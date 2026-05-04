import Foundation
import ExyteOpenAI
import SwiftUI
import Combine
import GRDB

@MainActor
class AIToolManager: ObservableObject {
    static let shared = AIToolManager()
    
    // Interaction state
    @Published var pendingAction: PendingAIAction?
    private var pendingContinuation: CheckedContinuation<String, Never>?
    
    private init() {}
    
    /// 清除所有挂起的 AI 动作（通常在清空对话时调用）
    func clearPendingActions() {
        if pendingContinuation != nil {
            pendingContinuation?.resume(returning: "Cancelled by user (Conversation cleared)")
            pendingContinuation = nil
        }
        pendingAction = nil
    }
    
    /// Get all available tool definitions for the AI (returned as JSON-serializable dictionaries)
    func getToolDefinitions() -> [[String: Any]] {
        return [
            [
                "type": "function",
                "function": [
                    "name": "get_workout_data",
                    "description": "获取特定日期区间的训练项目详情。支持查询普通单次训练项和每周重复训练计划。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "start_date": [
                                "type": "string",
                                "description": "起始日期 (格式: YYYY-MM-DD)"
                            ],
                            "end_date": [
                                "type": "string",
                                "description": "截止日期 (格式: YYYY-MM-DD)"
                            ],
                            "include_single_workouts": [
                                "type": "boolean",
                                "description": "是否包含普通单次训练项（即针对特定日期创建的项目）"
                            ],
                            "include_weekly_plans": [
                                "type": "boolean",
                                "description": "是否包含每周重复训练计划（即循环进行的训练任务）"
                            ]
                        ],
                        "required": ["start_date", "end_date", "include_single_workouts", "include_weekly_plans"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "execute_training_action",
                    "description": "对训练计划执行新增、修改操作。这是最后一步操作，调用后会弹出卡片请求用户确认。每次调用只能执行一种操作（create/edit）。注意：你不需要自己在回复中向用户确认，直接调用该 tool 即可，App 会自动弹出确认卡片。如果某个训练项从普通训练项改成重复训练项，App 会自动完成替换。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "action": [
                                "type": "string",
                                "enum": ["create", "edit"],
                                "description": "具体动作：create (新增), edit (修改)"
                            ],
                            "exercises": [
                                "type": "array",
                                "items": [
                                    "type": "object",
                                    "properties": [
                                        "target_date": [
                                            "type": "string",
                                            "description": "目标日期 (格式: YYYY-MM-DD)。如果是普通训练项则需要设置这个日期，如果是重复训练项则不需要设置。"
                                        ],
                                        "id": ["type": "string", "description": "训练项的数据库 ID。执行 edit (修改) 操作时必填，必须是查询得到的原始 ID (如 '12' 或 'repeat-5')。"],
                                        "name": ["type": "string", "description": "动作名称"],
                                        "sets": ["type": "integer", "description": "组数"],
                                        "trainingTime": ["type": "integer", "description": "单组训练时长(秒), -1为不限时"],
                                        "restTime": ["type": "integer", "description": "休息时长(秒)"],
                                        "tag": ["type": "integer", "description": "分类ID(1-6)"],
                                        "repeatDays": [
                                            "type": "array",
                                            "items": ["type": "integer"],
                                            "description": "周几重复(0=周日,1=周一,2=周二,3=周三,4=周四,5=周五,6=周六)"
                                        ]
                                    ],
                                    "required": ["name"]
                                ]
                            ]
                        ],
                        "required": ["action", "exercises"]
                    ]
                ]
            ],
            [
                "type": "function",
                "function": [
                    "name": "delete_training_item",
                    "description": "通过特定的一组 ID 删除训练项目。当你从查询结果中获得了一组项目的 ID 时，优先使用此工具进行删除。该操作会根据一组 ID 自动查出对应的训练项详情供用户确认是否删除。",
                    "parameters": [
                        "type": "object",
                        "properties": [
                            "ids": [
                                "type": "array",
                                "items": ["type": "string"],
                                "description": "要删除的项目 ID列表"
                            ]
                        ],
                        "required": ["ids"]
                    ]
                ]
            ]
        ]
    }
    
    /// Execute a tool by name and arguments
    func executeTool(name: String, arguments: [String: Any], sourceMessageId: String? = nil, toolCallId: String? = nil) async -> String {
        switch name {
        case "get_workout_data":
            return await queryTrainingPlans(arguments: arguments)
        case "execute_training_action":
            return await executeTrainingAction(arguments: arguments, sourceMessageId: sourceMessageId, toolCallId: toolCallId)
        case "delete_training_item":
            return await deleteTrainingItem(arguments: arguments, sourceMessageId: sourceMessageId, toolCallId: toolCallId)
        default:
            return "Error: Unknown tool \(name)"
        }
    }
    
    // MARK: - Tool Implementations
    
    private func executeTrainingAction(arguments: [String: Any], sourceMessageId: String?, toolCallId: String?) async -> String {
        guard let actionStr = arguments["action"] as? String,
              let exercisesDicts = arguments["exercises"] as? [[String: Any]] else {
            return "错误：缺少 action 或 exercises 参数"
        }
        
        // 1. Convert to internal PendingExerciseItem objects
        var exercises: [PendingExerciseItem] = []
        for dict in exercisesDicts {
            let id = dict["id"] as? String
            let name = dict["name"] as? String ?? "未知动作"
            let sets = dict["sets"] as? Int ?? ExerciseDefaults.sets
            let restTime = dict["restTime"] as? Int ?? (ExerciseDefaults.restMin * 60 + ExerciseDefaults.restSec)
            let trainingTime = dict["trainingTime"] as? Int ?? (ExerciseDefaults.isUnlimited ? -1 : (ExerciseDefaults.trainingMin * 60 + ExerciseDefaults.trainingSec))
            let tag = dict["tag"] as? Int ?? 1
            let rawRepeatDays = dict["repeatDays"] as? [Int] ?? []
            let repeatDays = rawRepeatDays
            
            let item = PendingExerciseItem(
                id: id,
                name: name,
                sets: sets,
                trainingTime: trainingTime,
                restTime: restTime,
                tag: tag,
                repeatDays: repeatDays,
                date: dict["target_date"] as? String
            )
            exercises.append(item)
        }
        
        let type: PendingAIAction.ActionType
        switch actionStr {
        case "create": type = .create
        case "edit": type = .edit
        default: return "错误：不支持的操作类型 \(actionStr)"
        }
        
        let action = PendingAIAction(id: toolCallId ?? UUID().uuidString, actionType: type, exercises: exercises, sourceMessageId: sourceMessageId)
        
        // 2. Wait for user interaction
        print("⏸ [AIToolManager] Waiting for user confirmation for action: \(action.actionType)")
        return await withCheckedContinuation { continuation in
            self.pendingAction = action
            self.pendingContinuation = continuation
        }
    }
    
    private func deleteTrainingItem(arguments: [String: Any], sourceMessageId: String?, toolCallId: String?) async -> String {
        guard let ids = arguments["ids"] as? [String] else {
            return "错误：缺少 ids 参数"
        }
        
        var exercises: [PendingExerciseItem] = []
        let allEx = ExerciseStore.shared.getAll()
        let dbPool = DatabaseManager.shared.dbPool
        
        for id in ids {
            // 1. Try finding in normal exercises
            if let ex = allEx.first(where: { $0.id == id }) {
                exercises.append(PendingExerciseItem(
                    id: ex.id,
                    name: ex.name,
                    sets: ex.sets,
                    trainingTime: ex.trainingTime,
                    restTime: ex.restTime,
                    tag: ex.tag,
                    repeatDays: [],
                    date: ex.date
                ))
            } 
            // 2. Try finding in weekly repeats
            else {
                do {
                    let repeatId = id.replacingOccurrences(of: "repeat-", with: "").components(separatedBy: "-").first ?? id
                    let plan = try await dbPool.read { db in
                        try WeeklyRepeatExercise.fetchOne(db, key: repeatId)
                    }
                    if let plan = plan {
                        exercises.append(PendingExerciseItem(
                            name: plan.name,
                            sets: plan.sets,
                            trainingTime: plan.trainingTime,
                            restTime: plan.restTime,
                            tag: plan.tag,
                            repeatDays: plan.repeatDays
                        ))
                    }
                } catch {
                    print("❌ [AIToolManager] Error fetching repeat plan: \(error)")
                }
            }
        }
        
        if exercises.isEmpty {
            return "错误：未找到指定的 ID，无法执行删除。"
        }
        
        let action = PendingAIAction(
            id: toolCallId ?? UUID().uuidString,
            actionType: .deleteById, 
            exercises: exercises, 
            sourceMessageId: sourceMessageId,
            targetIds: ids
        )
        
        print("⏸ [AIToolManager] Waiting for user confirmation for deletion of \(ids.count) items")
        return await withCheckedContinuation { continuation in
            self.pendingAction = action
            self.pendingContinuation = continuation
        }
    }
    
    /// Called from UI when user confirms or cancels
    func finishPendingAction(result: String) {
        print("▶️ [AIToolManager] Resuming pending continuation with result: \(result.prefix(100))...")
        self.pendingAction = nil
        if let cont = self.pendingContinuation {
            cont.resume(returning: result)
            self.pendingContinuation = nil
        } else {
            print("⚠️ [AIToolManager] No pending continuation found!")
        }
    }

    private func queryTrainingPlans(arguments: [String: Any]) async -> String {
        guard let startDate = arguments["start_date"] as? String,
              let endDate = arguments["end_date"] as? String else {
            return "Error: Missing required date parameters"
        }
        
        let includeSingle = arguments["include_single_workouts"] as? Bool ?? true
        let includeWeekly = arguments["include_weekly_plans"] as? Bool ?? true
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        
        guard let start = df.date(from: startDate), let end = df.date(from: endDate) else {
            return "Error: Invalid date format. Use YYYY-MM-DD."
        }
        
        let labelDf = DateFormatter()
        labelDf.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var sections: [String] = []
        
        // 1. Specific Exercises
        if includeSingle {
            let all = ExerciseStore.shared.getAll()
            let filtered = all.filter { ex in
                if let dateStr = ex.date, let d = df.date(from: dateStr) {
                    return d >= start && d <= end
                }
                return false
            }.sorted { ($0.date ?? "") < ($1.date ?? "") }
            
            if !filtered.isEmpty {
                var text = "### 普通训练项 (特定日期记录)\n"
                for ex in filtered {
                    let tagLabel = ex.tag != nil ? (ExerciseTag(rawValue: ex.tag!)?.label ?? "未分类") : "未分类"
                    let trainingLabel = ex.trainingTime == -1 ? "不限时" : "\(ex.trainingTime)秒"
                    let createdStr = labelDf.string(from: ex.createdAt)
                    let updatedStr = ex.updatedAt != nil ? labelDf.string(from: ex.updatedAt!) : "无"
                    let wrIdLabel = ex.weeklyRepeatId != nil ? "repeat-\(ex.weeklyRepeatId!)" : "无"
                    let actualSetsLabel = ex.actualSets != nil ? "\(ex.actualSets!)组" : "未记录"
                    let totalTimeLabel = ex.totalTime != nil ? "\(ex.totalTime!)秒" : "未记录"

                    text += """
                    - [ID: \(ex.id)]
                      日期: \(ex.date ?? "未知日期")
                      名称: \(ex.name)
                      计划: \(ex.sets)组, 训练: \(trainingLabel), 休息: \(ex.restTime)秒
                      实际完成: \(actualSetsLabel), 总耗时: \(totalTimeLabel)
                      状态: \(ex.completed ? "已完成" : "未完成")
                      分类: \(tagLabel)
                      创建时间: \(createdStr)
                      最后更新: \(updatedStr)
                      所属循环计划ID: \(wrIdLabel)
                    """
                    text += "\n"
                }
                sections.append(text)
            } else {
                sections.append("### 普通训练项\n该时段内无特定日期记录。")
            }
        }
        
        // 2. Weekly Repeats
        if includeWeekly {
            // Find which weekdays are spanned by the date range
            var weekdaysInRange = Set<Int>()
            let calendar = Calendar.current
            var current = calendar.startOfDay(for: start)
            let limit = calendar.startOfDay(for: end)
            
            // We only need to check up to 7 days to get all recurring possibilities
            var daysChecked = 0
            while current <= limit && daysChecked < 7 {
                weekdaysInRange.insert(calendar.component(.weekday, from: current) - 1)
                current = calendar.date(byAdding: .day, value: 1, to: current)!
                daysChecked += 1
            }
            
            // Build SQL query for weekdays
            let weekdayColumns = [
                0: "isSun", 1: "isMon", 2: "isTue", 3: "isWed", 4: "isThu", 5: "isFri", 6: "isSat"
            ]
            let conditions = weekdaysInRange.compactMap { weekdayColumns[$0] }.map { "\($0) = 1" }
            
            if !conditions.isEmpty {
                let weekdayClause = conditions.joined(separator: " OR ")
                
                do {
                    let dbPool = DatabaseManager.shared.dbPool
                    let calendar = Calendar.current
                    let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: end) ?? end
                    
                    let filtered = try await dbPool.read { db -> [WeeklyRepeatExercise] in
                        return try WeeklyRepeatExercise.fetchAll(db, sql: """
                            SELECT * FROM weekly_repeat_exercises 
                            WHERE (\(weekdayClause))
                              AND createdAt <= ?
                            """, arguments: [endOfDay])
                    }
                    
                    if !filtered.isEmpty {
                        var text = "### 重复训练计划 (每周循环)\n"
                        for plan in filtered {
                            let days = plan.repeatDays.sorted().map { day -> String in
                                switch day {
                                case 0: return "周日"; case 1: return "周一"; case 2: return "周二"; case 3: return "周三"; case 4: return "周四"; case 5: return "周五"; case 6: return "周六"
                                default: return "周\(day)"
                                }
                            }.joined(separator: ", ")
                            
                            let tagLabel = plan.tag != nil ? (ExerciseTag(rawValue: plan.tag!)?.label ?? "未分类") : "未分类"
                            let trainingLabel = plan.trainingTime == -1 ? "不限时" : "\(plan.trainingTime)秒"
                            let createdStr = labelDf.string(from: plan.createdAt)
                            let updatedStr = plan.updatedAt != nil ? labelDf.string(from: plan.updatedAt!) : "无"

                            text += """
                            - [ID: repeat-\(plan.id)]
                              计划名称: \(plan.name)
                              配置: \(plan.sets)组, 训练: \(trainingLabel), 休息: \(plan.restTime)秒
                              循环日: [\(days)]
                              分类: \(tagLabel)
                              创建时间: \(createdStr)
                              最后更新: \(updatedStr)
                            """
                            text += "\n"
                        }
                        sections.append(text)
                    } else {
                        sections.append("### 重复训练计划\n该时段内无有效的循环计划。")
                    }
                } catch {
                    print("❌ [AIToolManager] SQL query failed: \(error)")
                    sections.append("### 重复训练计划\n查询失败。")
                }
            } else {
                sections.append("### 重复训练计划\n日期跨度不足以包含任何循环日。")
            }
        }
        
        
        if sections.isEmpty {
            return "在 \(startDate) 到 \(endDate) 期间未找到任何训练数据。"
        }
        
        return sections.joined(separator: "\n\n")
    }
}
