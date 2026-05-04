import SwiftUI
import Combine
import ExyteOpenAI
import GRDB
import Foundation

// MARK: - AI Provider Configuration

enum AIProvider: String, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case claude = "Claude"
    case gemini = "Gemini"
    case doubao = "豆包"
    case qwen = "通义千问 (Qwen)"
    case hunyuan = "腾讯混元"
    case moonshot = "月之暗面 (Kimi)"
    case zhipu = "智谱 (GLM)"
    case minimax = "MiniMax"
    case deepseek = "DeepSeek"
    case custom = "自定义"
    
    var id: String { rawValue }
    
    var defaultBaseURL: String {
        switch self {
        case .openai: return "https://api.openai.com/v1"
        case .claude: return "https://api.anthropic.com"
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/models"
        case .doubao: return "https://ark.cn-beijing.volces.com/api/v3"
        case .qwen: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .hunyuan: return "https://api.hunyuan.cloud.tencent.com/v1"
        case .moonshot: return "https://api.moonshot.cn/v1"
        case .zhipu: return "https://open.bigmodel.cn/api/paas/v4"
        case .minimax: return "https://api.minimax.chat/v1"
        case .deepseek: return "https://api.deepseek.com"
        case .custom: return ""
        }
    }

    /// 端点后缀，拼接到 baseURL 后组成完整请求地址
    var chatEndpoint: String {
        switch self {
        case .claude: return "/v1/messages"
        case .gemini: return "" // Gemini URL 在 callChatAPI 内单独构造
        case .custom: return "" // 自定义：用户填写完整 URL，无需追加后缀
        default: return "/chat/completions"
        }
    }

    /// 完整的 Chat API 请求地址（用户只需填写 baseURL，后缀由代码封装）
    var chatCompletionURL: String {
        return baseURL + chatEndpoint
    }

    var baseURL: String {
        let custom = getCustomURL()
        if !custom.isEmpty { return custom }
        return defaultBaseURL
    }
    
    var defaultModel: String {
        switch self {
        case .openai: return "gpt-4o-mini"
        case .claude: return "claude-opus-4-6"
        case .gemini: return "gemini-1.5-flash"
        case .doubao: return "doubao-1.5-pro-32k-250115"
        case .qwen: return "qwen-plus"
        case .hunyuan: return "hunyuan-standard"
        case .moonshot: return "moonshot-v1-8k"
        case .zhipu: return "glm-4"
        case .minimax: return "MiniMax-M2.5"
        case .deepseek: return "deepseek-chat"
        case .custom: return "gpt-3.5-turbo"
        }
    }
    
    // Accounts for keychain
    internal static let keychainService = "com.fitnesstimerpro.ai"
    var apiKeyAccount: String { "ai_api_key_\(rawValue)" }
    var modelKeyAccount: String { "ai_model_\(rawValue)" }
    var urlKeyAccount: String { "ai_url_\(rawValue)" }
    var headersKeyAccount: String { "ai_headers_\(rawValue)" }

    func getAPIKey() -> String? {
        return KeychainHelper.shared.readString(service: Self.keychainService, account: apiKeyAccount)
    }
    func setAPIKey(_ key: String) {
        KeychainHelper.shared.saveString(key, service: Self.keychainService, account: apiKeyAccount)
    }
    func getModel() -> String {
        return KeychainHelper.shared.readString(service: Self.keychainService, account: modelKeyAccount) ?? defaultModel
    }
    func setModel(_ model: String) {
        KeychainHelper.shared.saveString(model, service: Self.keychainService, account: modelKeyAccount)
    }
    func getCustomURL() -> String {
        return KeychainHelper.shared.readString(service: Self.keychainService, account: urlKeyAccount) ?? ""
    }
    func setCustomURL(_ url: String) {
        KeychainHelper.shared.saveString(url, service: Self.keychainService, account: urlKeyAccount)
    }
    func getCustomHeaders() -> [String: String] {
        guard let json = KeychainHelper.shared.readString(service: Self.keychainService, account: headersKeyAccount),
              let data = json.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: String] else {
            return [:]
        }
        return dict
    }
    func setCustomHeaders(_ headers: [String: String]) {
        guard let data = try? JSONSerialization.data(withJSONObject: headers),
              let json = String(data: data, encoding: .utf8) else { return }
        KeychainHelper.shared.saveString(json, service: Self.keychainService, account: headersKeyAccount)
    }
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable, FetchableRecord, PersistableRecord {
    nonisolated static let databaseTableName = "chat_messages"
    let id: String
    let role: String      // "user", "assistant", "tool"
    let content: String?
    let reasoning: String? // Thinking process
    let toolCallId: String? // For role == "tool"
    let toolCalls: [ToolCallData]? // For role == "assistant"
    let timestamp: Date
    var isConfirmed: Bool? = nil // Persistence for AI action confirmation
    var isCancelled: Bool? = nil // Persistence for AI action cancellation
    var showSettingsBtn: Bool? = nil // Flag to show a settings button
    var confirmedPlansData: Data? = nil // JSON array of ConfirmedPlan
    var toolResults: [ToolResultData]? = nil // Store tool results in the same assistant record
    
    struct ToolResultData: Codable {
        let toolCallId: String
        let content: String
    }
    
    var confirmedPlans: [ConfirmedPlan] {
        guard let data = confirmedPlansData else { return [] }
        return (try? JSONDecoder().decode([ConfirmedPlan].self, from: data)) ?? []
    }
    
    struct ToolCallData: Codable, Identifiable {
        let id: String
        let name: String
        let arguments: String // JSON string
    }
    
    init(id: String? = nil, role: String, content: String?, reasoning: String? = nil, toolCallId: String? = nil, toolCalls: [ToolCallData]? = nil, showSettingsBtn: Bool? = nil, toolResults: [ToolResultData]? = nil, confirmedPlansData: Data? = nil) {
        self.id = id ?? UUID().uuidString
        self.role = role
        self.content = content
        self.reasoning = reasoning
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
        self.timestamp = Date()
        self.showSettingsBtn = showSettingsBtn
        self.toolResults = toolResults
        self.confirmedPlansData = confirmedPlansData
    }
    
    /// For API serialization
    var apiDict: [String: Any] {
        var dict: [String: Any] = ["role": role]
        if let content = content { dict["content"] = content }
        else { dict["content"] = NSNull() } // Explicit null for tool call messages
        
        if let tcid = toolCallId { dict["tool_call_id"] = tcid }
        if let tcalls = toolCalls {
            dict["tool_calls"] = tcalls.map { tc in
                [
                    "id": tc.id,
                    "type": "function",
                    "function": ["name": tc.name, "arguments": tc.arguments]
                ]
            }
        }
        return dict
    }
    
    // MARK: - GRDB Persistence
    
    enum DatabaseKeys: String, CodingKey {
        case id, role, content, reasoning, toolCallId, toolCallsData, timestamp
        case isConfirmed, isCancelled, showSettingsBtn, confirmedPlansData, toolResultsData
    }
    
    init(row: Row) {
        id = row["id"]
        role = row["role"]
        content = row["content"]
        reasoning = row["reasoning"]
        toolCallId = row["toolCallId"]
        timestamp = row["timestamp"]
        isConfirmed = row["isConfirmed"]
        isCancelled = row["isCancelled"]
        showSettingsBtn = row["showSettingsBtn"]
        confirmedPlansData = row["confirmedPlansData"]
        
        if let data: Data = row["toolResultsData"] {
            toolResults = try? JSONDecoder().decode([ToolResultData].self, from: data)
        } else {
            toolResults = nil
        }
        
        if let data: Data = row["toolCallsData"] {
            toolCalls = try? JSONDecoder().decode([ToolCallData].self, from: data)
        } else {
            toolCalls = nil
        }
    }
    
    func encode(to container: inout PersistenceContainer) {
        container["id"] = id
        container["role"] = role
        container["content"] = content
        container["reasoning"] = reasoning
        container["toolCallId"] = toolCallId
        container["timestamp"] = timestamp
        container["isConfirmed"] = isConfirmed
        container["isCancelled"] = isCancelled
        container["showSettingsBtn"] = showSettingsBtn
        container["confirmedPlansData"] = confirmedPlansData
        
        if let toolResults = toolResults {
            let data = try? JSONEncoder().encode(toolResults)
            container["toolResultsData"] = data
        } else {
            container["toolResultsData"] = nil
        }
        
        if let toolCalls = toolCalls {
            let data = try? JSONEncoder().encode(toolCalls)
            container["toolCallsData"] = data
        } else {
            container["toolCallsData"] = nil
        }
    }
}

// MARK: - Custom Provider Thinking Format

/// 自定义 provider 的思考格式，运行时从首次响应中自动检测
enum CustomThinkingFormat: String {
    case reasoningContent = "reasoning_content" // DeepSeek / Qwen / Kimi 等 OpenAI-compat 格式
    case reasoningDetails = "reasoning_details" // MiniMax 格式：delta.reasoning_details[].text
    case thinkTags        = "think_tags"        // <think>...</think> 内联标签
    case none             = "none"              // 模型不输出思考
    case detecting        = "detecting"         // 尚未检测（设置更改后的首次请求）
}

// MARK: - AI Response

struct AIStreamDelta {
    let content: String?
    let finishReason: String?
}

// MARK: - AI Service

@MainActor
class AIService: ObservableObject {
    static let shared = AIService()
    
    @Published var currentProvider: AIProvider = .openai {
        didSet {
            UserDefaults.standard.set(currentProvider.rawValue, forKey: "ai_current_provider")
        }
    }
    
    @Published var conversationHistory: [ChatMessage] = [] {
        didSet {
            // Requirement: Store every message immediately after it's received/sent.
            if conversationHistory.count > oldValue.count {
                let additions = conversationHistory.indices.suffix(conversationHistory.count - oldValue.count)
                for i in additions {
                    ChatMessageStore.shared.save(conversationHistory[i])
                }
            }
        }
    }
    @Published var isLoading: Bool = false
    @Published var currentStreamingText: String = ""
    @Published var currentStreamingReasoning: String = ""
    @Published var shouldCloseChat: Bool = false
    private var currentResolvingTask: Task<Void, Never>? = nil
    /// The ID of the current assistant message being generated/updated in the current turn
    @Published var currentTurnAssistantMessageId: String? = nil
    
    /// Temporarily stores confirmed plans until the next final assistant response
    private var pendingConfirmedPlans: [ConfirmedPlan]? = nil
    
    private let historyKey = "ai_conversation_history_cache"
    private let maxHistoryCount = 50 // Limit total stored messages to prevent cache bloat
    
    private var currentTask: URLSessionDataTask?

    // MARK: - Custom Provider Thinking Format Detection
    private var _customThinkingFormat: CustomThinkingFormat = .detecting
    private var _customThinkingSettingsKey: String = ""

    private func customThinkingSettingsKey() -> String {
        let url   = AIProvider.custom.getCustomURL()
        let model = AIProvider.custom.getModel()
        let hdrs  = AIProvider.custom.getCustomHeaders().keys.sorted().joined(separator: ",")
        return "\(url)|\(model)|\(hdrs)"
    }

    /// 返回当前自定义格式；若设置已变更则自动重置为 .detecting
    func resolveCustomThinkingFormat() -> CustomThinkingFormat {
        let key = customThinkingSettingsKey()
        if key != _customThinkingSettingsKey {
            _customThinkingSettingsKey = key
            _customThinkingFormat = .detecting
        }
        return _customThinkingFormat
    }

    func saveCustomThinkingFormat(_ format: CustomThinkingFormat) {
        _customThinkingFormat = format
        _customThinkingSettingsKey = customThinkingSettingsKey()
        UserDefaults.standard.set(format.rawValue, forKey: "custom_thinking_format")
        UserDefaults.standard.set(_customThinkingSettingsKey, forKey: "custom_thinking_format_key")
    }

    /// 从 fullResponse 中提取 <think>…</think> 内容，返回 (thinking, cleanedResponse)
    private func extractThinkTags(from text: String) -> (thinking: String, response: String) {
        var parts: [String] = []
        var remaining = text
        while let openRange  = remaining.range(of: "<think>"),
              let closeRange = remaining.range(of: "</think>",
                                               range: openRange.upperBound..<remaining.endIndex) {
            parts.append(String(remaining[openRange.upperBound..<closeRange.lowerBound]))
            remaining = String(remaining[remaining.startIndex..<openRange.lowerBound])
                      + String(remaining[closeRange.upperBound...])
        }
        return (
            parts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            remaining.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }

    private init() {
        // 1. Restore provider preference
        if let savedProvider = UserDefaults.standard.string(forKey: "ai_current_provider"),
           let provider = AIProvider(rawValue: savedProvider) {
            self.currentProvider = provider
        }

        // 2. Restore custom thinking format detection result
        let savedFormatKey = UserDefaults.standard.string(forKey: "custom_thinking_format_key") ?? ""
        let savedFormatRaw = UserDefaults.standard.string(forKey: "custom_thinking_format") ?? ""
        _customThinkingSettingsKey = savedFormatKey
        _customThinkingFormat = CustomThinkingFormat(rawValue: savedFormatRaw) ?? .detecting

        // 3. Load history from local cache asynchronously (Long-term memory)
        Task {
            await loadHistory()
        }
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        // Legacy method, now a no-op as we save in didSet
        print("AIService: Persistence is now handled immediately in didSet via ChatMessageStore.")
    }
    
    private func loadHistory() async {
        print("AIService: Loading latest 20 messages from ChatMessageStore...")
        let messages = ChatMessageStore.shared.getLatestMessages(limit: 20)
        
        await MainActor.run {
            self.conversationHistory = messages
            print("AIService: Successfully loaded \(messages.count) messages from persistence.")
        }
    }
    
    // MARK: - System Prompt
    
    static var systemPrompt: String {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let currentTime = df.string(from: Date())
        
        // Fetch current defaults
        let defaultSets = ExerciseDefaults.sets
        let defaultRest = ExerciseDefaults.restMin * 60 + ExerciseDefaults.restSec
        let defaultTraining = ExerciseDefaults.isUnlimited ? -1 : (ExerciseDefaults.trainingMin * 60 + ExerciseDefaults.trainingSec)
        
        return """
        你是「健身计时器」App 的 AI 规划助手。你的职责是帮助用户管理训练计划并提供专业健身建议。
        ## 现在的日期和时间
        \(currentTime)

        ## 训练项全局默认配置
        - 默认组数：\(defaultSets)
        - 默认训练时长：\(defaultTraining == -1 ? "不限时" : "\(defaultTraining)秒")
        - 默认休息时长：\(defaultRest)秒
        这些是用户在 App 设置中预设的默认值，当你创建新项目且用户未指定参数时，优先使用这些值。

        ## 核心能力
        1. **查询工具 (Native Tools)**：你可以查询用户的历史训练项目、每周重复计划。在给出任何修改建议或回答历史问题前，优先调用查询工具。
        2. **执行指令 (Native Tools)**：当用户要求创建、修改或删除训练项时，必须调用 `execute_training_action` 工具。这是最后一步操作。
        
        ## 动作执行规则
        - 每次只能执行一种动作（create、edit 或 delete）。
        - 调用该工具后，系统会挂起思考过程并等待用户在 UI 上点击确认。
        - 你会收到用户的最终确认结果（执行成功或已取消）。如果用户取消了操作，请礼貌地询问原因。
        - **千万不要在回复中手动编写 JSON 块，必须通过工具调用。**

        ## 参数说明
        - name: 动作名称
        - sets: 组数 (当前默认: \(defaultSets))
        - trainingTime: 时长 (秒, -1为不限时, 当前默认: \(defaultTraining))
        - restTime: 休息 (秒, 当前默认: \(defaultRest))
        - tag: 部位 (1=胸, 2=背, ... 6=腹)
        - repeatDays: 重复日 (0=周日, 1=周一, 2=周二, 3=周三, 4=周四, 5=周五, 6=周六)

        ## 重要规则
        - 始终使用中文。
        - 回复简洁、科学。涉及历史数据时必须基于查询结果。
        - **无需向用户进行二次确认**：当你确定用户想要执行某个修改动作时，直接调用工具即可。App 会自动弹出带有细节的确认卡片。
        - **数据删除限制**：你只能删除**今天及以后**的训练记录。如果用户让你删除过去的训练计划，请礼貌地回复“只能删除今天及以后的计划”。
        - **循环计划变更**：如果用户让你删除或修改以前就开始的重复训练计划，请明确告知用户该操作只会作用于今天以及未来。
        """
    }
    
    var isConfigured: Bool {
        if currentProvider == .custom {
            return !currentProvider.getCustomURL().isEmpty
        }
        let key = currentProvider.getAPIKey()
        return key != nil && !key!.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Public API
    
    /// Send a message and get streaming response
    func sendMessage(_ userMessage: String) async -> AsyncThrowingStream<String, Error> {
        let userMsg = ChatMessage(role: "user", content: userMessage)
        
        await MainActor.run {
            self.conversationHistory.append(userMsg)
            self.isLoading = true
            self.currentStreamingText = ""
            self.currentStreamingReasoning = ""
            
            // Pre-initialize the assistant message for this turn to get a fixed ID
            let initialAssistantMsg = ChatMessage(role: "assistant", content: "")
            self.currentTurnAssistantMessageId = initialAssistantMsg.id
            self.conversationHistory.append(initialAssistantMsg)
            // Note: The conversationHistory.didSet will handle the initial DB insertion
        }
        
        return AsyncThrowingStream { continuation in
            let resolvingTask = Task {
                do {
                    try await resolveResponse(continuation: continuation)
                } catch {
                    // Handle cancellation specifically
                    let isCancelled = (error is CancellationError) || 
                                     (error as NSError).code == NSURLErrorCancelled ||
                                     ((error as? AIServiceError) == nil && error.localizedDescription.contains("cancelled"))
                    
                    await MainActor.run {
                        self.isLoading = false
                        
                        // 如果正在清空（history 为空），则不添加任何撤销/错误消息，防止产生“灵异”消息
                        if isCancelled {
                            if !self.conversationHistory.isEmpty {
                                let finalContent = self.currentStreamingText.isEmpty ? "已取消" : "\(self.currentStreamingText) [已取消]"
                                let assistantMsg = ChatMessage(
                                    role: "assistant",
                                    content: finalContent,
                                    reasoning: self.currentStreamingReasoning.isEmpty ? nil : self.currentStreamingReasoning
                                )
                                self.conversationHistory.append(assistantMsg)
                            }
                        } else {
                            if !self.conversationHistory.isEmpty {
                                let errorMsg = "连接失败，请检查网络后重试"
                                let assistantMsg = ChatMessage(role: "assistant", content: errorMsg)
                                self.conversationHistory.append(assistantMsg)
                            }
                        }
                    }
                    continuation.finish()
                }
            }
            
            Task { @MainActor in
                self.currentResolvingTask = resolvingTask
            }
        }
    }
    
    private func resolveResponse(continuation: AsyncThrowingStream<String, Error>.Continuation, isInitialTurn: Bool = true, extraMessages: [[String: Any]] = []) async throws {
        // custom provider 通过自定义 Headers 完成鉴权，不强制要求 API Key
        let apiKey: String
        if self.currentProvider == .custom {
            apiKey = self.currentProvider.getAPIKey() ?? ""
        } else {
            guard let key = self.currentProvider.getAPIKey(), !key.isEmpty else {
                throw AIServiceError.noAPIKey
            }
            apiKey = key
        }
        
        let model = self.currentProvider.getModel()
        let messages = self.buildMessages() + extraMessages
        
        var attempts = 0
        let maxAttempts = 3
        var lastResult: (String, String, [ChatMessage.ToolCallData])?
        
        while attempts < maxAttempts {
            do {
                // Final response handling for potential tool loops
                let (fullResponse, fullReasoning, toolCalls) = try await self.callChatAPI(
                    baseURL: self.currentProvider.chatCompletionURL,
                    apiKey: apiKey,
                    model: model,
                    messages: messages,
                    continuation: continuation,
                    isInitialTurn: isInitialTurn
                )
                lastResult = (fullResponse, fullReasoning, toolCalls)
                break // Success!
            } catch {
                attempts += 1
                
                let isCancelled = (error is CancellationError) || 
                                 (error as NSError).code == NSURLErrorCancelled ||
                                 ((error as? AIServiceError) == nil && error.localizedDescription.contains("cancelled"))
                
                if isCancelled || attempts >= maxAttempts {
                    throw error
                }
                
                // Clear partial progress on UI before retry to avoid mess
                await MainActor.run {
                    self.currentStreamingText = "连接异常，正在重试 (\(attempts)/\(maxAttempts))..."
                }
                
                // 3 seconds delay
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
        
        guard let (fullResponse, fullReasoning, toolCalls) = lastResult else {
            throw AIServiceError.invalidResponse
        }
        
        // 1. Create the assistant's message (with either text or tool calls)
        // Reuse the same ID for this entire turn as requested
        let assistantMsg = ChatMessage(
            id: self.currentTurnAssistantMessageId ?? UUID().uuidString,
            role: "assistant", 
            content: fullResponse.isEmpty ? nil : fullResponse, 
            reasoning: fullReasoning.isEmpty ? nil : fullReasoning,
            toolCalls: toolCalls.isEmpty ? nil : toolCalls
        )

        // 2. If there are tool calls, execute them and continue the loop implicitly
        if !toolCalls.isEmpty {
            // Determine a descriptive message based on the tools being called
            let toolStatusMessage: String
            if let firstTool = toolCalls.first {
                switch firstTool.name {
                case "query_training_plans", "query_weekly_repeats":
                    toolStatusMessage = "正在执行训练计划查询工具..."
                case "delete_training_item":
                    toolStatusMessage = "正在执行训练计划删除工具..."
                case "execute_training_action":
                    let args = (try? JSONSerialization.jsonObject(with: firstTool.arguments.data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
                    let action = args["action"] as? String
                    if action == "create" {
                        toolStatusMessage = "正在执行训练计划新增工具..."
                    } else if action == "edit" {
                        toolStatusMessage = "正在执行训练计划修改工具..."
                    } else {
                        toolStatusMessage = "正在执行训练计划变更工具..."
                    }
                default:
                    toolStatusMessage = "正在执行工具..."
                }
            } else {
                toolStatusMessage = "正在执行工具..."
            }

            await MainActor.run {
                self.currentStreamingText = toolStatusMessage
            }
            
            var newExtraMessages = extraMessages
            var assistantDictForAPI = assistantMsg.apiDict
            if assistantMsg.toolCalls != nil {
                assistantDictForAPI["content"] = NSNull() // Standard for tool calls
            }
            newExtraMessages.append(assistantDictForAPI)
            
            for tool in toolCalls {
                // Parse arguments
                let args = (try? JSONSerialization.jsonObject(with: tool.arguments.data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
                let result = await AIToolManager.shared.executeTool(name: tool.name, arguments: args, sourceMessageId: assistantMsg.id, toolCallId: tool.id)
                print("🔍 [AIService] Tool execution result: \(result.prefix(100))...")
                
                // Update the shared turn message with the tool result (satisfy 'same ID' requirement)
                if let idx = self.conversationHistory.firstIndex(where: { $0.id == assistantMsg.id }) {
                    var updatedMsg = self.conversationHistory[idx]
                    var currentResults = updatedMsg.toolResults ?? []
                    currentResults.append(ChatMessage.ToolResultData(toolCallId: tool.id, content: result))
                    updatedMsg.toolResults = currentResults
                    
                    // Update UI and DB
                    await MainActor.run {
                        self.conversationHistory[idx] = updatedMsg
                    }
                    ChatMessageStore.shared.save(updatedMsg)
                }
                
                // Still need to pass individual messages to the next API turn
                newExtraMessages.append([
                    "role": "tool",
                    "tool_call_id": tool.id,
                    "content": result
                ])
            }
            
            // Recurse to get next response after tools, passing the whole turn's context implicitly
            print("🔄 [AIService] Recursively calling resolveResponse after tool execution (implicit context)")
            // Clear currentStreamingText before recursion so state message doesn't persist
            await MainActor.run {
                self.currentStreamingText = ""
            }
            try await resolveResponse(continuation: continuation, isInitialTurn: false, extraMessages: newExtraMessages)
        } else {
            // This is a final response (no more tool calls)
            var finalAssistantMsg = assistantMsg
            if let pending = self.pendingConfirmedPlans {
                finalAssistantMsg.confirmedPlansData = try? JSONEncoder().encode(pending)
                self.pendingConfirmedPlans = nil
            }
            
            // Final save for the completed message
            ChatMessageStore.shared.save(finalAssistantMsg)
            
            await MainActor.run {
                // If it already exists, replace it to update UI, otherwise append
                if let idx = self.conversationHistory.firstIndex(where: { $0.id == finalAssistantMsg.id }) {
                    self.conversationHistory[idx] = finalAssistantMsg
                } else if !self.conversationHistory.isEmpty {
                    self.conversationHistory.append(finalAssistantMsg)
                }
                self.isLoading = false
                self.currentTurnAssistantMessageId = nil // Clear for next user input
            } 
            continuation.finish()
        } 
    }
    
    /// Updated to use streaming for consistency
    @discardableResult
    func sendMessageSimple(_ userMessage: String) async -> String {
        let stream = await sendMessage(userMessage)
        var fullText = ""
        do {
            for try await chunk in stream {
                fullText += chunk
            }
        } catch {
            print("❌ [AIService] sendMessageSimple stream error: \(error)")
        }
        return fullText
    }
    
    /// Clear conversation and reset
    func clearConversation() {
        print("AIService: Clearing conversation history...")
        
        // 1. 取消进行中的请求与任务
        cancelRequest()
        
        // 2. 清空运行状态
        conversationHistory.removeAll()
        currentTurnAssistantMessageId = nil
        currentStreamingText = ""
        currentStreamingReasoning = ""
        isLoading = false
        
        // 3. 清空持久化存储
        ChatMessageStore.shared.clearHistory()
        
        // 4. 清理工具管理器挂起的状态
        AIToolManager.shared.clearPendingActions()
        
        print("AIService: Conversation history cleared.")
    }
    
    func markMessageAsConfirmed(id: String, plans: [ConfirmedPlan]?) {
        if let index = conversationHistory.firstIndex(where: { $0.id == id }) {
            conversationHistory[index].isConfirmed = true
            if let newPlans = plans {
                var currentPlans = self.pendingConfirmedPlans ?? []
                // Append and avoid duplicates if somehow called with same data
                for p in newPlans {
                    if !currentPlans.contains(where: { $0.id == p.id }) {
                        currentPlans.append(p)
                    }
                }
                self.pendingConfirmedPlans = currentPlans
            }
            ChatMessageStore.shared.update(conversationHistory[index])
        }
    }
    
    func markMessageAsCancelled(id: String) {
        if let index = conversationHistory.firstIndex(where: { $0.id == id }) {
            conversationHistory[index].isCancelled = true
            ChatMessageStore.shared.update(conversationHistory[index])
        }
    }
    

    func cancelRequest() {
        currentResolvingTask?.cancel()
        currentResolvingTask = nil
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
    }
    
    // MARK: - Private Helpers
    
    private func buildMessages() -> [[String: Any]] {
        var messages: [[String: Any]] = []
        
        // System prompt
        messages.append(["role": "user", "content": Self.systemPrompt])
        
        // Keep last 20 messages for context (to avoid token overflow)
        let recentHistory = conversationHistory.suffix(20)
        for msg in recentHistory {
            // Expand merged turns into API message sequences
            if let toolCalls = msg.toolCalls {
                // 1. The Assistant call message
                var assistantDict = msg.apiDict
                assistantDict["content"] = NSNull() // Clear content for tool call part if needed by some APIs, but we'll follow standard
                messages.append(assistantDict)
                
                // 2. The Tool results
                if let results = msg.toolResults {
                    for res in results {
                        messages.append([
                            "role": "tool",
                            "tool_call_id": res.toolCallId,
                            "content": res.content
                        ])
                    }
                }
                
                // 3. The final response (if any content exists)
                if let content = msg.content, !content.isEmpty {
                    messages.append(["role": "assistant", "content": content])
                }
            } else {
                messages.append(msg.apiDict)
            }
        }
        
        return messages
    }
    
    private func buildAnthropicMessages() -> [[String: Any]] {
        var anthropicMessages: [[String: Any]] = []
        let recentHistory = conversationHistory.suffix(20)
        
        for msg in recentHistory {
            var content: [[String: Any]] = []
            
            // Text content
            if let text = msg.content, !text.isEmpty {
                content.append(["type": "text", "text": text])
            }
            
            // Tool calls (Assistant sent these)
            if let toolCalls = msg.toolCalls {
                for tc in toolCalls {
                    if let args = try? JSONSerialization.jsonObject(with: tc.arguments.data(using: .utf8) ?? Data()) as? [String: Any] {
                        content.append([
                            "type": "tool_use",
                            "id": tc.id,
                            "name": tc.name,
                            "input": args
                        ])
                    }
                }
            }
            
            // Tool results (This message IS the results)
            if msg.role == "tool", let tcid = msg.toolCallId, let text = msg.content {
                // Anthropic requires tool results to be in a separate "user" message with a specific structure
                anthropicMessages.append([
                    "role": "user",
                    "content": [[
                        "type": "tool_result",
                        "tool_use_id": tcid,
                        "content": text
                    ]]
                ])
                continue
            }
            
            // Merged tool results in assistant message
            if msg.role == "assistant", let results = msg.toolResults {
                // These actually need to be sent as a following USER message in Anthropic
                // But since we store them in the assistant msg for UI, we handle it during conversion
                if !content.isEmpty {
                    anthropicMessages.append(["role": "assistant", "content": content])
                }
                
                let resultsContent = results.map { res in
                    ["type": "tool_result", "tool_use_id": res.toolCallId, "content": res.content]
                }
                anthropicMessages.append(["role": "user", "content": resultsContent])
                continue
            }
            
            if !content.isEmpty {
                anthropicMessages.append(["role": msg.role == "tool" ? "user" : msg.role, "content": content])
            }
        }
        return anthropicMessages
    }
    
    private func buildGeminiContents() -> [[String: Any]] {
        var contents: [[String: Any]] = []
        let recentHistory = conversationHistory.suffix(20)
        
        for msg in recentHistory {
            var parts: [[String: Any]] = []
            
            if let text = msg.content, !text.isEmpty {
                parts.append(["text": text])
            }
            
            if let toolCalls = msg.toolCalls {
                for tc in toolCalls {
                    let args = (try? JSONSerialization.jsonObject(with: tc.arguments.data(using: .utf8) ?? Data()) as? [String: Any]) ?? [:]
                    parts.append([
                        "functionCall": [
                            "name": tc.name,
                            "args": args
                        ]
                    ])
                }
            }
            
            if msg.role == "tool", let tcid = msg.toolCallId, let text = msg.content {
                parts.append([
                    "functionResponse": [
                        "name": "unknown", // Gemini usually matches by name, but we don't store name in the tool msg directly easily
                        "response": ["content": text]
                    ]
                ])
            }
            
            if msg.role == "assistant", let results = msg.toolResults {
                // Finish the model parts
                if !parts.isEmpty {
                    contents.append(["role": "model", "parts": parts])
                }
                
                // Add the function responses
                let responsesParts = results.map { res -> [String: Any] in
                    // Try to find the tool name from the assistant msg's tool calls
                    let name = msg.toolCalls?.first(where: { $0.id == res.toolCallId })?.name ?? "unknown"
                    return [
                        "functionResponse": [
                            "name": name,
                            "response": ["content": res.content]
                        ]
                    ]
                }
                contents.append(["role": "user", "parts": responsesParts])
                continue
            }
            
            if !parts.isEmpty {
                let role = msg.role == "assistant" ? "model" : "user"
                contents.append(["role": role, "parts": parts])
            }
        }
        return contents
    }
    
    private func convertToolsToAnthropic(_ tools: [[String: Any]]) -> [[String: Any]] {
        return tools.compactMap { dict in
            guard let function = dict["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let description = function["description"] as? String,
                  let parameters = function["parameters"] as? [String: Any] else { return nil }
            
            return [
                "name": name,
                "description": description,
                "input_schema": parameters
            ]
        }
    }
    
    private func convertToolsToGemini(_ tools: [[String: Any]]) -> [[String: Any]] {
        let declarations = tools.compactMap { dict -> [String: Any]? in
            guard let function = dict["function"] as? [String: Any],
                  let name = function["name"] as? String,
                  let description = function["description"] as? String,
                  let parameters = function["parameters"] as? [String: Any] else { return nil }
            
            return [
                "name": name,
                "description": description,
                "parameters": parameters
            ]
        }
        return [["function_declarations": declarations]]
    }
    
    // MARK: - Streaming API Call
    
    private func callChatAPI(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        continuation: AsyncThrowingStream<String, Error>.Continuation,
        isInitialTurn: Bool = true
    ) async throws -> (String, String, [ChatMessage.ToolCallData]) {
        let provider = self.currentProvider
        var requestURL = baseURL
        
        // Final URL construction
        if provider == .gemini {
            requestURL = "\(baseURL)/\(model):streamGenerateContent?key=\(apiKey)"
        }
        
        guard let url = URL(string: requestURL) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        
        if provider == .claude {
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
            let anthropicMessages = buildAnthropicMessages()
            let systemPrompts = messages.filter { ($0["role"] as? String) == "user" && ($0["content"] as? String)?.contains("你是「健身计时器」") == true }
            let systemContent = systemPrompts.compactMap { $0["content"] as? String }.joined(separator: "\n")
            
            body = [
                "model": model,
                "messages": anthropicMessages,
                "system": systemContent,
                "stream": true,
                "max_tokens": 16000
            ]
            // Extended thinking：对支持的 Claude 模型自动启用（claude-3-7-sonnet / opus-4 / sonnet-4）
            let supportsThinking = ["claude-opus-4", "claude-sonnet-4", "claude-3-7-sonnet"]
                .contains(where: { model.lowercased().contains($0) })
            if supportsThinking {
                body["thinking"] = ["type": "enabled", "budget_tokens": 10000] as [String: Any]
            }
            let tools = AIToolManager.shared.getToolDefinitions()
            if !tools.isEmpty {
                body["tools"] = convertToolsToAnthropic(tools)
            }
        } else if provider == .gemini {
            let contents = buildGeminiContents()
            body = [
                "contents": contents,
                "generationConfig": [
                    "temperature": 0.7,
                    "maxOutputTokens": 4096,
                    "thinkingConfig": ["includeThoughts": true]  // 思考模型返回 thought:true parts
                ] as [String: Any]
            ]
            let tools = AIToolManager.shared.getToolDefinitions()
            if !tools.isEmpty {
                body["tools"] = convertToolsToGemini(tools)
            }
        } else {
            // OpenAI and others（custom provider 通过自定义 Headers 鉴权，不自动注入）
            if provider != .custom {
                request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            }
            body = [
                "model": model,
                "messages": messages,
                "stream": true,
                "temperature": 0.7,
                "max_tokens": 4096
            ]
            let tools = AIToolManager.shared.getToolDefinitions()
            if !tools.isEmpty {
                body["tools"] = tools
            }
        }
        
        // 注入自定义 Headers（仅 custom provider）
        if provider == .custom {
            for (key, value) in provider.getCustomHeaders() {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }

        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        print("📡 [AIService] API Request (\(provider.rawValue)): \(requestURL)")
        print("  - Headers: \(request.allHTTPHeaderFields ?? [:])")
        if let bodyData = request.httpBody, let bodyString = String(data: bodyData, encoding: .utf8) {
            print("  - Body: \(bodyString)")
        }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            var errorData = Data()
            for try await byte in bytes {
                errorData.append(byte)
            }
            let errorBody = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            print("❌ [AIService] API Error - Status: \(httpResponse.statusCode)")
            print("  - Response Body: \(errorBody)")
            
            if let json = try? JSONSerialization.jsonObject(with: errorData) as? [String: Any] {
                if let errorObj = json["error"] as? [String: Any],
                   let message = errorObj["message"] as? String {
                    throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: message)
                } else if let errorMsg = json["message"] as? String {
                    throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
                }
            }
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
        }
        
        // If it's a recursive turn and currentStreamingText is just a status message, don't inherit it
        let isStatusMessage = self.currentStreamingText.contains("正在执行") || self.currentStreamingText.contains("工具")
        var fullResponse = isInitialTurn ? "" : ((self.currentStreamingText.isEmpty || isStatusMessage) ? "" : self.currentStreamingText + "\n")
        var fullReasoning = isInitialTurn ? "" : (self.currentStreamingReasoning.isEmpty ? "" : self.currentStreamingReasoning + "\n---\n")
        var toolCallsTemp: [Int: (id: String, name: String, args: String)] = [:]
        var hasDetectedToolCall = false
        var chunkSaveCounter = 0

        // 自定义 provider 思考格式检测
        let customFmt: CustomThinkingFormat = provider == .custom ? resolveCustomThinkingFormat() : .none
        let isDetectingCustom = provider == .custom && customFmt == .detecting
        // 检测阶段用于记录实际触发的字段来源
        var detectedReasoningSource: CustomThinkingFormat = .none
        var isInThinkBlock = false

        for try await line in bytes.lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            if provider == .claude {
                // Anthropic Stream Parsing
                if line.hasPrefix("event: ") { continue }
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                
                guard let jsonData = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let type = json["type"] as? String else {
                    continue
                }
                
                if type == "content_block_delta", let delta = json["delta"] as? [String: Any] {
                    let deltaType = delta["type"] as? String ?? ""
                    if deltaType == "thinking_delta", let thinking = delta["thinking"] as? String {
                        // Claude extended thinking block
                        fullReasoning += thinking
                        await MainActor.run { self.currentStreamingReasoning = fullReasoning }
                    } else if let text = delta["text"] as? String {
                        // text_delta (or legacy plain text)
                        fullResponse += text
                        await MainActor.run { self.currentStreamingText = fullResponse }
                        continuation.yield(text)
                    }
                    if let partialArgs = delta["partial_json"] as? String {
                        if let index = json["index"] as? Int {
                            toolCallsTemp[index, default: ("", "", "")].args += partialArgs
                        }
                    }
                } else if type == "content_block_start", let block = json["content_block"] as? [String: Any],
                          let bType = block["type"] as? String, bType == "tool_use" {
                    if let index = json["index"] as? Int, let id = block["id"] as? String, let name = block["name"] as? String {
                        toolCallsTemp[index] = (id, name, "")
                        hasDetectedToolCall = true
                    }
                } else if type == "message_stop" {
                    break
                }
            } else if provider == .gemini {
                // Gemini Stream Parsing (JSON chunks)
                guard let jsonData = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let candidates = json["candidates"] as? [[String: Any]],
                      let first = candidates.first,
                      let content = first["content"] as? [String: Any],
                      let parts = content["parts"] as? [[String: Any]] else {
                    continue
                }
                
                for part in parts {
                    if let isThought = part["thought"] as? Bool, isThought {
                        // Gemini thinking model: thought:true part
                        if let text = part["text"] as? String {
                            fullReasoning += text
                            await MainActor.run { self.currentStreamingReasoning = fullReasoning }
                        }
                    } else if let text = part["text"] as? String {
                        fullResponse += text
                        await MainActor.run { self.currentStreamingText = fullResponse }
                        continuation.yield(text)
                    }
                    if let fCall = part["functionCall"] as? [String: Any],
                       let name = fCall["name"] as? String {
                        hasDetectedToolCall = true
                        // Gemini doesn't always provide index or ID in the same way; 
                        // we'll use a sequential ID for compatibility
                        let callId = "gemini-\(UUID().uuidString.prefix(8))"
                        let argsDict = fCall["args"] as? [String: Any] ?? [:]
                        let argsData = try? JSONSerialization.data(withJSONObject: argsDict)
                        let argsStr = String(data: argsData ?? Data(), encoding: .utf8) ?? "{}"
                        
                        let nextIdx = toolCallsTemp.keys.sorted().last.map { $0 + 1 } ?? 0
                        toolCallsTemp[nextIdx] = (callId, name, argsStr)
                    }
                }
            } else {
                // OpenAI / SSE Standard Stream Parsing
                guard line.hasPrefix("data: ") else { continue }
                let jsonStr = String(line.dropFirst(6))
                
                if jsonStr == "[DONE]" { break }
                
                guard let jsonData = jsonStr.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                      let choices = json["choices"] as? [[String: Any]],
                      let first = choices.first,
                      let delta = first["delta"] as? [String: Any] else {
                    continue
                }
                
                // Handle Thinking/Reasoning
                if let reasoning = delta["reasoning_content"] as? String ?? delta["reasoning"] as? String {
                    // DeepSeek / Qwen / Kimi / GLM / Hunyuan / Doubao / OpenAI-o 系列
                    fullReasoning += reasoning
                    await MainActor.run { self.currentStreamingReasoning = fullReasoning }
                    if isDetectingCustom && detectedReasoningSource == .none { detectedReasoningSource = .reasoningContent }
                } else if let details = delta["reasoning_details"] as? [[String: Any]] {
                    // MiniMax: delta.reasoning_details[].text
                    let reasonText = details.compactMap { $0["text"] as? String }.joined()
                    if !reasonText.isEmpty {
                        fullReasoning += reasonText
                        await MainActor.run { self.currentStreamingReasoning = fullReasoning }
                        if isDetectingCustom && detectedReasoningSource == .none { detectedReasoningSource = .reasoningDetails }
                    }
                }
                
                // Handle Tool Calls (Streaming)
                if let tcalls = delta["tool_calls"] as? [[String: Any]] {
                    if !hasDetectedToolCall {
                        hasDetectedToolCall = true
                        if !fullResponse.isEmpty {
                            fullReasoning += (fullReasoning.isEmpty ? "" : "\n") + fullResponse
                            fullResponse = ""
                            await MainActor.run {
                                self.currentStreamingText = ""
                                self.currentStreamingReasoning = fullReasoning
                            }
                        }
                    }
                    
                    for tc in tcalls {
                        guard let index = tc["index"] as? Int else { continue }
                        if let id = tc["id"] as? String {
                            toolCallsTemp[index, default: ("", "", "")].id = id
                        }
                        if let function = tc["function"] as? [String: Any] {
                            if let name = function["name"] as? String {
                                toolCallsTemp[index, default: ("", "", "")].name += name
                            }
                            if let args = function["arguments"] as? String {
                                toolCallsTemp[index, default: ("", "", "")].args += args
                            }
                        }
                    }
                }
                
                // Handle Content
                if let text = delta["content"] as? String {
                    if hasDetectedToolCall {
                        fullReasoning += text
                        await MainActor.run { self.currentStreamingReasoning = fullReasoning }
                    } else {
                        // 正常的标签分流逻辑
                        var remainingText = text
                        
                        while !remainingText.isEmpty {
                            if !isInThinkBlock {
                                if let startRange = remainingText.range(of: "<think>") {
                                    // <think> 之前的部分是正文
                                    let preThink = String(remainingText[..<startRange.lowerBound])
                                    if !preThink.isEmpty {
                                        fullResponse += preThink
                                        await MainActor.run { self.currentStreamingText = fullResponse }
                                        continuation.yield(preThink)
                                    }
                                    
                                    isInThinkBlock = true
                                    remainingText = String(remainingText[startRange.upperBound...])
                                } else {
                                    // 纯正文
                                    fullResponse += remainingText
                                    await MainActor.run { self.currentStreamingText = fullResponse }
                                    continuation.yield(remainingText)
                                    remainingText = ""
                                }
                            } else {
                                if let endRange = remainingText.range(of: "</think>") {
                                    // </think> 之前的部分是思考过程
                                    let reasoningPart = String(remainingText[..<endRange.lowerBound])
                                    fullReasoning += reasoningPart
                                    await MainActor.run { self.currentStreamingReasoning = fullReasoning }
                                    
                                    isInThinkBlock = false
                                    remainingText = String(remainingText[endRange.upperBound...])
                                } else {
                                    // 纯思考内容
                                    fullReasoning += remainingText
                                    await MainActor.run { self.currentStreamingReasoning = fullReasoning }
                                    remainingText = ""
                                }
                            }
                        }
                    }
                }
                
                if let finishReason = first["finish_reason"] as? String, finishReason == "stop" || finishReason == "tool_calls" {
                    break
                }
            }
            
            // Shared Incremental Save logic
            chunkSaveCounter += 1
            if chunkSaveCounter >= 4 { // Slightly higher threshold for performance
                chunkSaveCounter = 0
                if let msgId = self.currentTurnAssistantMessageId {
                    let existingMsg = self.conversationHistory.first(where: { $0.id == msgId })
                    let msg = ChatMessage(
                        id: msgId,
                        role: "assistant",
                        content: fullResponse.isEmpty ? nil : fullResponse,
                        reasoning: fullReasoning.isEmpty ? nil : fullReasoning,
                        toolCalls: existingMsg?.toolCalls,
                        toolResults: existingMsg?.toolResults,
                        confirmedPlansData: existingMsg?.confirmedPlansData
                    )
                    ChatMessageStore.shared.save(msg)
                }
            }
        }
        
        // 自定义 provider：流结束后处理思考格式检测 / <think> 标签提取
        if provider == .custom {
            if isDetectingCustom {
                // 按优先级判断检测到的格式
                let detectedFormat: CustomThinkingFormat
                if detectedReasoningSource != .none {
                    // 已通过 reasoning_content 或 reasoning_details 字段检测到
                    detectedFormat = detectedReasoningSource
                } else if fullResponse.contains("<think>") {
                    // <think>…</think> 内联标签
                    let (thinking, cleaned) = extractThinkTags(from: fullResponse)
                    if !thinking.isEmpty {
                        fullReasoning = thinking
                        fullResponse  = cleaned
                        await MainActor.run {
                            self.currentStreamingReasoning = fullReasoning
                            self.currentStreamingText = fullResponse
                        }
                        detectedFormat = .thinkTags
                    } else {
                        detectedFormat = .none
                    }
                } else {
                    detectedFormat = .none
                }
                saveCustomThinkingFormat(detectedFormat)
                print("🔍 [AIService] 自定义 provider 思考格式检测完成：\(detectedFormat.rawValue)")
            } else if customFmt == .thinkTags {
                // 已知 thinkTags 格式，流结束后提取标签
                let (thinking, cleaned) = extractThinkTags(from: fullResponse)
                if !thinking.isEmpty {
                    fullReasoning = fullReasoning.isEmpty ? thinking : fullReasoning + "\n" + thinking
                    fullResponse  = cleaned
                    await MainActor.run {
                        self.currentStreamingReasoning = fullReasoning
                        self.currentStreamingText = fullResponse
                    }
                }
            }
        }

        // Final incremental save at end of stream chunk
        if let msgId = self.currentTurnAssistantMessageId {
            // Merge detected tool calls with existing ones
            let existingMsg = self.conversationHistory.first(where: { $0.id == msgId })
            var mergedToolCalls = existingMsg?.toolCalls ?? []
            for tc in toolCallsTemp.values {
                let newData = ChatMessage.ToolCallData(id: tc.id, name: tc.name, arguments: tc.args)
                if !mergedToolCalls.contains(where: { $0.id == tc.id }) {
                    mergedToolCalls.append(newData)
                }
            }
            
            let intermediateMsg = ChatMessage(
                id: msgId,
                role: "assistant",
                content: fullResponse.isEmpty ? nil : fullResponse,
                reasoning: fullReasoning.isEmpty ? nil : fullReasoning,
                toolCalls: mergedToolCalls.isEmpty ? nil : mergedToolCalls,
                toolResults: existingMsg?.toolResults,
                confirmedPlansData: existingMsg?.confirmedPlansData
            )
            ChatMessageStore.shared.update(intermediateMsg)
        }
        
        let finalToolCalls = toolCallsTemp.values.map { 
            ChatMessage.ToolCallData(id: $0.id, name: $0.name, arguments: $0.args)
        }
        
        return (fullResponse, fullReasoning, finalToolCalls)
    }
    
    // MARK: - Non-Streaming API Call (for internal processing)
    
    private func callChatAPINonStream(
        baseURL: String,
        apiKey: String,
        model: String,
        messages: [[String: Any]],
        isInitialTurn: Bool = true
    ) async throws -> (String, String, [ChatMessage.ToolCallData]) {
        let provider = self.currentProvider
        var requestURL = baseURL
        
        if provider == .gemini {
            requestURL = "\(baseURL)/\(model):generateContent?key=\(apiKey)"
        }
        
        guard let url = URL(string: requestURL) else {
            throw AIServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        
        if provider == .claude {
            request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            let anthropicMessages = buildAnthropicMessages()
            let systemPrompts = messages.filter { ($0["role"] as? String) == "user" && ($0["content"] as? String)?.contains("你是「健身计时器」") == true }
            let systemContent = systemPrompts.compactMap { $0["content"] as? String }.joined(separator: "\n")
            body = ["model": model, "messages": anthropicMessages, "system": systemContent, "stream": false, "max_tokens": 4096]
            let tools = AIToolManager.shared.getToolDefinitions()
            if !tools.isEmpty { body["tools"] = convertToolsToAnthropic(tools) }
        } else if provider == .gemini {
            let contents = buildGeminiContents()
            body = ["contents": contents, "generationConfig": ["temperature": 0.7, "maxOutputTokens": 4096]]
            let tools = AIToolManager.shared.getToolDefinitions()
            if !tools.isEmpty { body["tools"] = convertToolsToGemini(tools) }
        } else {
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            body = ["model": model, "messages": messages, "stream": false, "temperature": 0.7, "max_tokens": 4096]
            let tools = AIToolManager.shared.getToolDefinitions()
            if !tools.isEmpty { body["tools"] = tools }
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AIServiceError.invalidResponse
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AIServiceError.parseFailed
        }
        
        var fullResponse = ""
        var fullReasoning = ""
        var finalToolCalls: [ChatMessage.ToolCallData] = []
        
        if provider == .claude {
            if let contentArray = json["content"] as? [[String: Any]] {
                for item in contentArray {
                    if let text = item["text"] as? String { fullResponse += text }
                    if let type = item["type"] as? String, type == "tool_use",
                       let id = item["id"] as? String, let name = item["name"] as? String,
                       let input = item["input"] as? [String: Any] {
                        let argsData = try? JSONSerialization.data(withJSONObject: input)
                        let argsStr = String(data: argsData ?? Data(), encoding: .utf8) ?? "{}"
                        finalToolCalls.append(ChatMessage.ToolCallData(id: id, name: name, arguments: argsStr))
                    }
                }
            }
        } else if provider == .gemini {
            if let candidates = json["candidates"] as? [[String: Any]], let first = candidates.first,
               let content = first["content"] as? [String: Any], let parts = content["parts"] as? [[String: Any]] {
                for part in parts {
                    if let text = part["text"] as? String { fullResponse += text }
                    if let fCall = part["functionCall"] as? [String: Any], let name = fCall["name"] as? String {
                        let id = "gemini-\(UUID().uuidString.prefix(8))"
                        let argsDict = fCall["args"] as? [String: Any] ?? [:]
                        let argsData = try? JSONSerialization.data(withJSONObject: argsDict)
                        let argsStr = String(data: argsData ?? Data(), encoding: .utf8) ?? "{}"
                        finalToolCalls.append(ChatMessage.ToolCallData(id: id, name: name, arguments: argsStr))
                    }
                }
            }
        } else {
            // OpenAI standard
            if let choices = json["choices"] as? [[String: Any]], let first = choices.first,
               let message = first["message"] as? [String: Any] {
                fullResponse = message["content"] as? String ?? ""
                if let tcalls = message["tool_calls"] as? [[String: Any]] {
                    for tc in tcalls {
                        if let function = tc["function"] as? [String: Any],
                           let name = function["name"] as? String,
                           let args = function["arguments"] as? String,
                           let id = tc["id"] as? String {
                            finalToolCalls.append(ChatMessage.ToolCallData(id: id, name: name, arguments: args))
                        }
                    }
                }
            }
        }
        
        return (fullResponse, fullReasoning, finalToolCalls)
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case parseFailed
    case noAPIKey
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API 地址，请检查设置中的自定义 URL"
        case .invalidResponse:
            return "无效的服务器响应"
        case .apiError(let code, let message):
            if code == 401 { return "API Key 校验失败，请检查设置" }
            if code == 429 { return "请求过于频繁或额度已用尽" }
            return "服务器返回错误 (\(code)): \(message)"
        case .parseFailed:
            return "无法解析 AI 响应数据"
        case .noAPIKey:
            return "未配置 API Key，请前往设置页面配置"
        }
    }
}
