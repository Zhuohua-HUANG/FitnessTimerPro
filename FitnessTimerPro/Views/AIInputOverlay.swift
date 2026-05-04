import SwiftUI
import AVFoundation

struct AIInputOverlay: View {
    @EnvironmentObject var manager: WorkoutManager
    @ObservedObject var aiService = AIService.shared
    @ObservedObject var toolManager = AIToolManager.shared

    @State private var aiInputText = ""
    @State private var showChatSheet = false
    @FocusState private var isAIInputFocused: Bool
    @AppStorage("isAICreatorEnabled") private var isAICreatorEnabled = true
    @AppStorage("hasAcceptedAIAgreement") private var hasAcceptedAIAgreement = false
    @State private var pendingAction: PendingAIAction? = nil
    /// 标记当前展示的训练方案是否是从对话历史中打开的
    @State private var isPlanFromHistory: Bool = false
    @State private var showAgreementDialog = false
    @State private var pendingTextAfterAgreement: String? = nil
    @State private var isOpeningChatFromAgreement = false
    
    var body: some View {
        if isAICreatorEnabled {
            ZStack(alignment: .bottom) {
                // Background Chat View
                if showChatSheet {
                    AIChatView(
                        isPresented: $showChatSheet,
                        onShowPlanForMessage: { msg in
                            // This handles legacy unconfirmed action links
                            self.parseAndExecuteActions(msg, isFromHistory: true)
                        },
                        onShowConfirmedPlan: { plan in
                            self.showConfirmedPlanFromHistory(plan)
                        },
                        onSendMessage: { text in
                            // Pre-fill and send
                            aiInputText = text
                            sendAIMessage()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(0)
                }
                
                mainOverlay
                    .zIndex(1)
                // Action confirmation overlay
                if pendingAction != nil {
                    AIActionConfirmationView(
                        pendingAction: $pendingAction,
                        onConfirm: { exercises in
                            executeConfirmedActions(exercises)
                        },
                        onCancel: {
                            handleActionCancelled()
                        },
                        showBackButton: isPlanFromHistory,
                        onBack: isPlanFromHistory ? {
                            withAnimation {
                                pendingAction = nil
                                isPlanFromHistory = false
                            }
                        } : nil
                    )
                    .environmentObject(manager)
                    .zIndex(3)
                }

                // AI Service Agreement Dialog
                if showAgreementDialog {
                    StandardDialog(
                        title: "使用 AI 服务",
                        message: "本功能将使用第三方 AI 服务生成内容，您的输入会发送至第三方 AI 服务器处理。是否同意？",
                        primaryTitle: "同意",
                        primaryIsWhite: false,
                        primaryAction: {
                            hasAcceptedAIAgreement = true
                            showAgreementDialog = false
                            if isOpeningChatFromAgreement {
                                withAnimation {
                                    showChatSheet = true
                                }
                                isOpeningChatFromAgreement = false
                            } else if let text = pendingTextAfterAgreement {
                                sendAIMessage(customText: text)
                                pendingTextAfterAgreement = nil
                            }
                        },
                        secondaryTitle: "不同意",
                        secondaryAction: {
                            showAgreementDialog = false
                            pendingTextAfterAgreement = nil
                            isOpeningChatFromAgreement = false
                        }
                    )
                    .zIndex(4)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showChatSheet)
            .animation(.easeInOut(duration: 0.25), value: pendingAction != nil)
            .onReceive(toolManager.$pendingAction) { action in
                if let newAction = action, pendingAction?.id != newAction.id {
                    withAnimation {
                        isPlanFromHistory = false
                        self.pendingAction = newAction
                    }
                } else if action == nil && pendingAction != nil {
                    withAnimation {
                        self.pendingAction = nil
                    }
                }
            }
        }
    }

    private var mainOverlay: some View {
        ZStack {
            // Background tap to dismiss keyboard while allowing scroll
            if isAIInputFocused {
                BackgroundTapView {
                    isAIInputFocused = false
                }
                .edgesIgnoringSafeArea(.all)
                .zIndex(-1)
            }
            
            // Dismiss layer safely removed to allow scrolling background scrollview.
            
            VStack(spacing: 0) {
                Spacer()
                
                // Content Area
                VStack(spacing: 0) {

                    
                    HStack {
                        Spacer()
                        
                        // Capsule Input Bar
                        HStack(spacing: 0) {
                            // 1. Chat icon (Left side now)
                            Button(action: {
                                if !hasAcceptedAIAgreement {
                                    isOpeningChatFromAgreement = true
                                    showAgreementDialog = true
                                } else {
                                    isAIInputFocused = false
                                    withAnimation {
                                        showChatSheet.toggle()
                                    }
                                }
                            }) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(aiService.isLoading ? AppColors.blue : .white)
                            }
                            .padding(.leading, 16)
                            .transition(.scale.combined(with: .opacity))

                            TextField("帮你编辑或者制定训练计划", text: $aiInputText, axis: .vertical)
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .lineLimit(1...10)
                                .padding(.leading, 12)
                                .padding(.trailing, 8)
                                .padding(.vertical, 14)
                                .focused($isAIInputFocused)
                                .onSubmit {
                                    sendAIMessage()
                                }
                            
                            // 2. Right side: Send / Stop button
                            if aiService.isLoading && showChatSheet {
                                // Stop button
                                Button(action: {
                                    aiService.cancelRequest()
                                }) {
                                    Image(systemName: "stop.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.white)
                                }
                                .padding(.trailing, 10)
                                .transition(.scale.combined(with: .opacity))
                            } else {
                                // Send / Input button (Always on right)
                                Button(action: { sendAIMessage() }) {
                                    Image(systemName: "arrow.up.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(AppColors.blue)
                                        .opacity(aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading ? 0.3 : 1.0)
                                }
                                .padding(.trailing, 10)
                                .disabled(aiInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || aiService.isLoading)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 28).fill(Color(hex: "222222")))
                        .overlay(RoundedRectangle(cornerRadius: 28).stroke(Color.gray.opacity(0.4), lineWidth: 1))
                        .shadow(color: .black.opacity(1), radius: 10, x: 0, y: 0)
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Actions


    
    private func sendAIMessage(customText: String? = nil) {
        let text = (customText ?? aiInputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !aiService.isLoading else { return }
        
        // 0. Check agreement first
        if !hasAcceptedAIAgreement {
            pendingTextAfterAgreement = text
            isOpeningChatFromAgreement = false
            showAgreementDialog = true
            return
        }
        
        if customText == nil {
            aiInputText = ""
        }
        isAIInputFocused = false
        
        // Open the chat sheet to show the conversation
        showChatSheet = true
        
        // 1. Check configuration
        if !aiService.isConfigured {
            let userMsg = ChatMessage(role: "user", content: text)
            let assistantMsg = ChatMessage(
                role: "assistant", 
                content: "您还没有配置 \(aiService.currentProvider.rawValue) 的 API。请点击下方的按钮去进行配置：",
                showSettingsBtn: true
            )
            aiService.conversationHistory.append(userMsg)
            aiService.conversationHistory.append(assistantMsg)
            return
        }
        
        // 2. Send the message
        Task {
            await aiService.sendMessageSimple(text)
        }
    }
    
    // MARK: - Parse AI Response
    
    private func parseAndExecuteActions(_ message: ChatMessage, isFromHistory: Bool = false) {
        var jsonStr: String? = nil
        
        // 1. Try to extract JSON from tool calls
        if let toolCalls = message.toolCalls, 
           let actionTool = toolCalls.first(where: { $0.name == "execute_training_action" }) {
            jsonStr = actionTool.arguments
        }
        
        guard let validJsonStr = jsonStr,
              let data = validJsonStr.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let action = json["action"] as? String,
              let exercises = json["exercises"] as? [[String: Any]] else {
            return
        }
        
        guard let actionType = PendingAIAction.ActionType(rawValue: action) else { return }
        
        let pendingExercises = exercises.compactMap { ex -> PendingExerciseItem? in
            guard let name = ex["name"] as? String else { return nil }
            return PendingExerciseItem(
                name: name,
                sets: ex["sets"] as? Int ?? 4,
                trainingTime: ex["trainingTime"] as? Int ?? -1,
                restTime: ex["restTime"] as? Int ?? 60,
                tag: ex["tag"] as? Int,
                repeatDays: ex["repeatDays"] as? [Int] ?? [],
                date: ex["target_date"] as? String
            )
        }
        
        guard !pendingExercises.isEmpty else { return }
        
        // Show confirmation dialog instead of executing directly
        withAnimation {
            isPlanFromHistory = isFromHistory
            pendingAction = PendingAIAction(
                id: message.id, // Using message ID for correlation
                actionType: actionType,
                exercises: pendingExercises,
                isConfirmed: message.isConfirmed ?? false,
                isCancelled: message.isCancelled ?? false,
                sourceMessageId: message.id
            )
        }
    }
    
    // MARK: - History Display Handlers
    
    /// Display a confirmed plan from the chat history databases
    private func showConfirmedPlanFromHistory(_ plan: ConfirmedPlan) {
        withAnimation {
            isPlanFromHistory = true
            
            // Reconstruct the pending action from the saved confirmed snapshot
            let actionType: PendingAIAction.ActionType
            switch plan.actionType {
            case "create": actionType = .create
            case "edit": actionType = .edit
            case "deleteById": actionType = .deleteById
            default: actionType = .create // Fallback
            }
            
            pendingAction = PendingAIAction(
                id: plan.id, // Preserve original plan ID
                actionType: actionType,
                exercises: plan.exercises,
                isConfirmed: true, // It's historically confirmed
                isCancelled: false,
                sourceMessageId: nil, // Doesn't need to re-save to message
                targetIds: plan.actionType == "deleteById" ? plan.exercises.compactMap { $0.id } : nil
            )
        }
    }
    
    // MARK: - Confirm / Cancel Handlers
    
    private func handleActionCancelled() {
        guard let action = pendingAction else { return }
        
        withAnimation {
            pendingAction?.isCancelled = true
        }
        
        if let msgId = action.sourceMessageId {
            aiService.markMessageAsCancelled(id: msgId)
        }
        
        AIToolManager.shared.finishPendingAction(result: "用户返回/取消了该计划。请询问用户取消的原因或根据建议进行调整。")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                pendingAction = nil
            }
        }
    }
    
    /// Overriding to also finish the tool continuation
    private func executeConfirmedActions(_ exercises: [PendingExerciseItem]) {
        guard let action = pendingAction else { return }
        
        // Store result message before clearing
        let resultMsg: String
        var confirmedPlans: [ConfirmedPlan] = []
        
        switch action.actionType {
        case .create:
            // Execute create
            for ex in exercises {
                if !ex.repeatDays.isEmpty {
                    manager.addWeeklyRepeat(
                        name: ex.name,
                        sets: ex.sets,
                        rest: ex.restTime,
                        trainingTime: ex.trainingTime,
                        repeatDays: ex.repeatDays,
                        tag: ex.tag
                    )
                } else {
                    manager.addExercise(
                        name: ex.name,
                        sets: ex.sets,
                        rest: ex.restTime,
                        trainingTime: ex.trainingTime,
                        tag: ex.tag,
                        date: ex.date
                    )
                }
            }
            manager.showToast("已创建 \(exercises.count) 个训练项", style: .success)
            resultMsg = "用户已确认，执行成功。成功创建了 \(exercises.count) 个训练项。"
            confirmedPlans.append(ConfirmedPlan(id: UUID().uuidString, actionType: "create", title: "创建方案: \(exercises.count) 项", exercises: exercises))
            
        case .edit:
            var updatedCount = 0
            for ex in exercises {
                if let targetId = ex.id {
                    manager.saveSettings(
                        id: targetId,
                        name: ex.name,
                        sets: ex.sets,
                        rest: ex.restTime,
                        trainingTime: ex.trainingTime,
                        repeatDays: ex.repeatDays.isEmpty ? nil : ex.repeatDays,
                        tag: ex.tag,
                        date: ex.date
                    )
                    updatedCount += 1
                }
            }
            if updatedCount > 0 {
                manager.showToast("已修改 \(updatedCount) 个训练项目", style: .success)
                resultMsg = "用户已确认，执行成功。修改了 \(updatedCount) 个训练项。"
                confirmedPlans.append(ConfirmedPlan(id: UUID().uuidString, actionType: "edit", title: "修改方案: \(updatedCount) 项", exercises: exercises))
            } else {
                manager.showToast("修改失败：未提供 ID", style: .error)
                resultMsg = "用户已确认，但由于未提供有效的项目 ID，未能执行修改。"
            }
            
        case .deleteById:
            let ids = action.targetIds ?? []
            var deletedCount = 0
            for id in ids {
                manager.deleteExercise(id: id)
                deletedCount += 1
            }
            if deletedCount > 0 {
                manager.showToast("已删除 \(deletedCount) 个训练项目", style: .success)
                resultMsg = "用户已确认，执行成功。已通过 ID 删除了 \(deletedCount) 个指定的训练项。"
                confirmedPlans.append(ConfirmedPlan(id: UUID().uuidString, actionType: "deleteById", title: "删除方案: \(deletedCount) 项", exercises: exercises))
            } else {
                manager.showToast("未找到指定项目", style: .error)
                resultMsg = "用户已确认，执行失败。未找到指定 ID 的项目。"
            }
        default:
            resultMsg = "用户已确认操作。"
        }
        
        withAnimation {
            pendingAction?.isConfirmed = true
        }
        
        if let msgId = action.sourceMessageId {
            aiService.markMessageAsConfirmed(id: msgId, plans: confirmedPlans.isEmpty ? nil : confirmedPlans)
        }
        print("✅ [AIInputOverlay] User confirmed the action (\(action.actionType)). Result message: \(resultMsg)")
        
        // 确保不会因为后续连续触发网络请求阻断动画的执行，将 ToolManager 抛回 AI 的操作独立至后台或作短暂延时
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            AIToolManager.shared.finishPendingAction(result: resultMsg)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                pendingAction = nil
            }
        }
    }
}

// MARK: - Helper Views

/// A view that detects taps and executes a closure without blocking touches (like scrolls) to views below.
struct BackgroundTapView: UIViewRepresentable {
    var onTap: () -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let gesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        // This allows scrolling/dragging below to still work
        gesture.cancelsTouchesInView = false
        view.addGestureRecognizer(gesture)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onTap: onTap)
    }

    class Coordinator: NSObject {
        var onTap: () -> Void
        init(onTap: @escaping () -> Void) { self.onTap = onTap }
        @objc func handleTap() {
            onTap()
        }
    }
}
