import SwiftUI

// 自定义样式的 DatePicker 包装器，用于实现 13px 字体
struct CustomCompactDatePicker: View {
    @Binding var selection: Date
    
    var body: some View {
        ZStack(alignment: .leading) {
            // 真实的 DatePicker，设为透明但保留点击
            DatePicker("", selection: $selection, displayedComponents: .date)
                .labelsHidden()
                .datePickerStyle(.compact)
                .opacity(0.015)
                .scaleEffect(x: 1.2, y: 1.0)
            
            // 自定义显示的 UI，满足 13px 字体要求
            HStack(spacing: 4) {
                Text(selection, style: .date)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .allowsHitTesting(false) // 让点击穿透到下层的 DatePicker
        }
    }
}

// MARK: - Pending AI Action Model

struct PendingExerciseItem: Identifiable, Codable {
    let internalId = UUID()
    var id: String? = nil // Database ID for edits
    var name: String
    var sets: Int
    var trainingTime: Int  // -1 for unlimited
    var restTime: Int
    var tag: Int?
    var repeatDays: [Int]
    var date: String? // Target date for single workouts (YYYY-MM-DD)
    
    enum CodingKeys: String, CodingKey {
        case id, name, sets, trainingTime, restTime, tag, repeatDays, date
    }
}

// Data structure to hold the confirmed snapshot in the database
struct ConfirmedPlan: Codable, Identifiable {
    let id: String
    let actionType: String // "create", "edit", "deleteById"
    let title: String
    let exercises: [PendingExerciseItem]
}

struct PendingAIAction: Identifiable {
    let id: String
    let actionType: ActionType
    var exercises: [PendingExerciseItem]
    var isConfirmed: Bool = false
    var isCancelled: Bool = false
    var sourceMessageId: String? = nil
    var targetIds: [String]? = nil // 用于直接通过 ID 删除
    enum ActionType: String {
        case create = "create"
        case edit = "edit"
        case deleteById = "delete_by_id" // 新增通过 ID 删除的类型
        
        var title: String {
            switch self {
            case .create: return "创建训练项"
            case .edit: return "修改训练项"
            case .deleteById: return "删除训练项"
            }
        }
        
        var icon: String {
            switch self {
            case .create: return "plus.circle.fill"
            case .edit: return "pencil.circle.fill"
            case .deleteById: return "trash.circle.fill"
            }
        }
        
        var accentColor: Color {
            switch self {
            case .create: return AppColors.blue
            case .edit: return .orange
            case .deleteById: return .red
            }
        }
    }
}

// MARK: - Confirmation View

struct AIActionConfirmationView: View {
    @EnvironmentObject var manager: WorkoutManager
    @Binding var pendingAction: PendingAIAction?
    var onConfirm: ([PendingExerciseItem]) -> Void
    var onCancel: () -> Void
    /// 是否是从对话历史中手动打开的方案（而不是 AI tool 直接触发）
    var showBackButton: Bool = false
    /// 可选的返回回调，仅在 `showBackButton == true` 时传入
    var onBack: (() -> Void)? = nil
    
    var body: some View {
        if let action = pendingAction {
            ZStack {
                // Dim background
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {} // Prevent tap-through
                
                VStack(spacing: 0) {
                    // Header，支持可选返回按钮
                    ZStack {
                        HStack {
                            if showBackButton {
                                Button(action: {
                                    onBack?()
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .padding(8)
                                }
                            } else {
                                // 占位，保持标题居中
                                Spacer()
                                    .frame(width: 32)
                            }
                            
                            Spacer()
                            
                            Text("\(action.exercises.count) 项")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .padding(.trailing, 8)
                        }
                        .padding(.horizontal, 12)
                        
                        Text(action.actionType == .create ? "训练计划新增方案" : 
                             (action.actionType == .deleteById ? "训练计划删除方案" : "训练计划修改方案"))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 12)
                    

                    // Exercise list
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(action.exercises.indices, id: \.self) { index in
                                ConfirmationExerciseCard(
                                    item: bindingForExercise(at: index),
                                    actionType: action.actionType,
                                    // 删除操作在确认前后都只读，避免误编辑，但仍展示完整详情
                                    isReadOnly: action.isConfirmed || action.isCancelled || action.actionType == .deleteById,
                                    onDelete: {
                                        removeExercise(at: index)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .frame(maxHeight: 400)
                    

                    // Action buttons
                    if action.isConfirmed || action.isCancelled {
                        // Already resolved state
                        HStack {
                            if action.isCancelled {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                Text("已取消")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.gray)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(action.actionType.accentColor)
                                Text("已确认\(action.actionType.title)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(action.actionType.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    } else {
                        HStack(spacing: 12) {
                            Button(action: onCancel) {
                                Text("不满意")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                            
                            Button(action: {
                                if let action = pendingAction {
                                    onConfirm(action.exercises)
                                }
                            }) {
                                Text("确认\(action.actionType.title)")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(action.actionType.accentColor)
                                    .cornerRadius(12)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                }
                .background(AppColors.darkGray)
                .cornerRadius(20)
                .padding(.horizontal, 20)
                .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 10)
            }
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
        }
    }
    
    private func bindingForExercise(at index: Int) -> Binding<PendingExerciseItem> {
        Binding(
            get: { pendingAction?.exercises[index] ?? PendingExerciseItem(name: "", sets: 4, trainingTime: -1, restTime: 60, repeatDays: []) },
            set: { pendingAction?.exercises[index] = $0 }
        )
    }
    
    private func removeExercise(at index: Int) {
        pendingAction?.exercises.remove(at: index)
        if pendingAction?.exercises.isEmpty == true {
            onCancel()
        }
    }
}

// MARK: - Exercise Card

struct ConfirmationExerciseCard: View {
    @Binding var item: PendingExerciseItem
    let actionType: PendingAIAction.ActionType
    var isReadOnly: Bool = false
    var onDelete: () -> Void
    
    let allWeekdays = [
        (0, "日"), (1, "一"), (2, "二"), (3, "三"), (4, "四"), (5, "五"), (6, "六")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let dateStr = item.date, !dateStr.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    // Text("目标日期")
                    //     .font(.system(size: 13))
                    //     .foregroundColor(.gray)
                    
                    let isRepeatSelected = !item.repeatDays.isEmpty
                    let dateBinding = Binding<Date>(
                        get: {
                            let df = DateFormatter()
                            df.dateFormat = "yyyy-MM-dd"
                            return df.date(from: item.date ?? "") ?? Date()
                        },
                        set: { newDate in
                            let df = DateFormatter()
                            df.dateFormat = "yyyy-MM-dd"
                            item.date = df.string(from: newDate)
                        }
                    )
                    
                    CustomCompactDatePicker(selection: dateBinding)
                        .disabled(isRepeatSelected || isReadOnly)
                        .opacity(isRepeatSelected ? 0.3 : 1.0)
                        .colorScheme(.dark)
                }
            }

            // Name row
            HStack {
                if isReadOnly {
                    Text(item.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    TextField("训练名称", text: $item.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                if !isReadOnly {
                    Button(action: onDelete) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray.opacity(0.6))
                    }
                }
            }
            
            // Tag selector
            HStack(spacing: 6) {
                ForEach(ExerciseTag.allCases, id: \.rawValue) { tag in
                    Button(action: {
                        if !isReadOnly {
                            item.tag = item.tag == tag.rawValue ? nil : tag.rawValue
                        }
                    }) {
                        Text(tag.label)
                            .font(.system(size: 12, weight: .bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(item.tag == tag.rawValue ? AppColors.blue.opacity(isReadOnly ? 0.4 : 1) : Color.white.opacity(0.08))
                            .foregroundColor(item.tag == tag.rawValue ? .white.opacity(isReadOnly ? 0.5 : 1) : .gray)
                            .cornerRadius(14)
                    }
                    .disabled(isReadOnly)
                }
            }
                        // Target Date Picker

            
            // 训练参数与重复日期（包含删除操作在内，始终展示详情；根据 isReadOnly 控制是否可编辑）
            VStack(spacing: 12) {
                paramField(label: "组数", value: $item.sets, suffix: "组", stretch: true)
                paramField(label: "训练时间", value: $item.trainingTime, suffix: "秒", stretch: true)
                paramField(label: "休息时间", value: $item.restTime, suffix: "秒", stretch: true)
            }
            
            // Repeat days
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("重复")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    HStack(spacing: 6) {
                        ForEach(allWeekdays, id: \.0) { day in
                            let isSelected = item.repeatDays.contains(day.0)
                            Button(action: {
                                if !isReadOnly {
                                    if isSelected {
                                        item.repeatDays.removeAll { $0 == day.0 }
                                    } else {
                                        item.repeatDays.append(day.0)
                                        item.repeatDays.sort()
                                        // Clear date string if repeat is selected (optional logic, but follows prompt's "disabled" spirit)
                                    }
                                }
                            }) {
                                Text(day.1)
                                    .font(.system(size: 12, weight: .bold))
                                    .frame(width: 32, height: 32)
                                    .background(isSelected ? AppColors.blue.opacity(isReadOnly ? 0.4 : 1) : Color.white.opacity(0.08))
                                    .foregroundColor(isSelected ? .white.opacity(isReadOnly ? 0.5 : 1) : .gray)
                                    .clipShape(Circle())
                            }
                            .disabled(isReadOnly)
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
        .cornerRadius(14)
    }
    
    @ViewBuilder
    private func paramField(label: String, value: Binding<Int>, suffix: String, stretch: Bool = false) -> some View {
        // 训练 / 休息：标题和时间加减分成两行
        if label == "训练时间" || label == "休息时间" {
            VStack(alignment: .leading, spacing: 6) {
                // 第 1 行：标题 + 不限时开关（仅训练且可编辑时显示）
                HStack {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    
                    
                    if label == "训练时间", !isReadOnly {
                        Button(action: {
                            if value.wrappedValue == -1 {
                                value.wrappedValue = 60
                            } else {
                                value.wrappedValue = -1
                            }
                        }) {
                            Text("不限时")
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(value.wrappedValue == -1 ? AppColors.blue : Color.white.opacity(0.1))
                                .foregroundColor(value.wrappedValue == -1 ? .white : .gray)
                                .cornerRadius(6)
                        }
                    } else if label == "训练时间", isReadOnly, value.wrappedValue == -1 {
                        // 只读且为不限时时，在标题行右侧提示
                        Text("不限时")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.gray)
                    }
                }
                
                // 第 2 行：时间/休息的数值与加减
                HStack(spacing: 8) {
                    if isReadOnly {
                        if value.wrappedValue == -1 {
                            Text("∞")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        } else {
                            Text("\(value.wrappedValue)\(suffix)")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                    } else {
                        HStack(spacing: 4) {
                            Button(action: {
                                if value.wrappedValue != -1 && value.wrappedValue > 1 {
                                    value.wrappedValue -= (suffix == "秒" ? 5 : 1)
                                    if value.wrappedValue < 1 { value.wrappedValue = 1 }
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(value.wrappedValue == -1 ? Color.gray.opacity(0.3) : .gray)
                            }
                            .disabled(value.wrappedValue == -1)
                            
                            if value.wrappedValue == -1 {
                                Text("∞")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 40, alignment: .center)
                            } else {
                                Text("\(value.wrappedValue)\(suffix)")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.white)
                                    .frame(minWidth: 40, alignment: .center)
                            }
                            
                            Button(action: {
                                if value.wrappedValue != -1 {
                                    value.wrappedValue += (suffix == "秒" ? 5 : 1)
                                }
                            }) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 20))
                                    .foregroundColor(value.wrappedValue == -1 ? Color.gray.opacity(0.3) : .gray)
                            }
                            .disabled(value.wrappedValue == -1)
                        }
                        Spacer()
                    }
                }
            }
        } else {
            // 组数等：加减紧挨着参数名左侧对齐
            HStack(spacing: 12) {
                Text(label)
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
                
                if isReadOnly {
                    if value.wrappedValue == -1 {
                        Text("∞")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        Text("\(value.wrappedValue)\(suffix)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    }
                } else {
                    HStack(spacing: 4) {
                        Button(action: {
                            if value.wrappedValue > 1 {
                                value.wrappedValue -= 1
                            }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                        
                        Text("\(value.wrappedValue)\(suffix)")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                            .frame(minWidth: 40, alignment: .center)
                        
                        Button(action: {
                            value.wrappedValue += 1
                        }) {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        }
                    }
                }
                
                Spacer()
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        if seconds <= 0 { return "0s" }
        let m = seconds / 60
        let s = seconds % 60
        var result = ""
        if m > 0 { result += "\(m)m" }
        if s > 0 { result += "\(s)s" }
        return result
    }
}
