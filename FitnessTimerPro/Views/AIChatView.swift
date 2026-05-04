import SwiftUI
import AVFoundation
import MarkdownUI

// MARK: - AI Chat Sheet View

struct AIChatView: View {
    @EnvironmentObject var manager: WorkoutManager
    @ObservedObject var aiService = AIService.shared
    @Binding var isPresented: Bool
    var onShowPlanForMessage: ((ChatMessage) -> Void)? = nil
    var onShowConfirmedPlan: ((ConfirmedPlan) -> Void)? = nil
    var onSendMessage: ((String) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            chatHeader
            
            // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 20) {
                            let history = Array(aiService.conversationHistory.suffix(20))
                            
                            if !history.isEmpty || aiService.isLoading {
                                Text("仅展示最新 20 条对话记录")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray.opacity(0.6))
                                    .padding(.top, 8)
                            }
                            
                            if history.isEmpty && !aiService.isLoading {
                                // 第一次进入或已清空对话时，展示主题与推荐 Query
                                welcomeView
                            } else {
                                ForEach(history.filter { $0.id != aiService.currentTurnAssistantMessageId }) { msg in
                                    ChatBubble(
                                        message: msg,
                                        additionalMessages: [],
                                        onShowPlan: {
                                            if (msg.content ?? "").contains("```json") || (msg.toolCalls ?? []).contains { $0.name == "execute_training_action" } || (msg.toolCalls ?? []).contains { $0.name == "delete_training_item" } {
                                                onShowPlanForMessage?(msg)
                                            }
                                        },
                                        onShowConfirmedPlan: { plan in
                                            onShowConfirmedPlan?(plan)
                                        }
                                    )
                                    .id(msg.id)
                                }
                                
                                // Streaming indicator
                                if aiService.isLoading {
                                    streamingBubble
                                        .id("streaming")
                                }
                            }
                        }
                        .padding(.horizontal) 
                        .padding(.vertical, 16)
                        .padding(.bottom, 20)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    // Removed ignoresSafeArea(.keyboard) to allow ScrollView to resize with keyboard
                    .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: aiService.conversationHistory.count) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: aiService.currentStreamingText) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onChange(of: aiService.currentStreamingReasoning) { _, _ in
                        scrollToBottom(proxy: proxy)
                    }
                    .onAppear {
                        // Scroll to bottom immediately when view is opened
                        scrollToBottom(proxy: proxy)
                    }
                }
            
            // Bottom spacer (70px) to push content up
            Color.clear.frame(height: 72)
        }
        .background(AppColors.darkGray)
        .onOpenURL { url in
            if url.scheme == "settings" && url.host == "ai" {
                withAnimation {
                    isPresented = false
                    manager.currentView = .settings
                    manager.settingsPath = [.aiSettings]
                }
            }
        }
        .onChange(of: aiService.shouldCloseChat) { oldValue, newValue in
            if newValue {
                withAnimation {
                    isPresented = false
                    aiService.shouldCloseChat = false // Reset
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("CloseAIChatAndGoToSettings"))) { _ in
            withAnimation {
                isPresented = false
                manager.currentView = .settings
                manager.settingsPath = [.aiSettings]
            }
        }
    }
    
    // MARK: - Sub-views
    
    private var chatHeader: some View {
        ZStack {
            HStack {
                // Close Button
                Button(action: {
                    withAnimation {
                        isPresented = false
                    }
                }) {
                    Image(systemName: "chevron.down")
                        .font(.title3)
                        .foregroundColor(.white)
                        .padding(8)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            VStack(spacing: 2) {
                Text("AI 规划助手")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                Text("内容由 AI 生成，仅供参考")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 14)
        .background(AppColors.darkGray)
    }
    
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle")
                .font(.system(size: 40))
                .foregroundColor(AppColors.blue)
            
            Text("你好，我是 AI 规划助手")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("我可以帮你快速创建、调整训练计划，或者提供专业的健身建议。")
                .font(.system(size: 16))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            // Quick action buttons
            VStack(spacing: 10) {
                quickActionButton("帮我制定一个胸部训练计划")
                quickActionButton("推荐一个适合新手的全身训练")
                quickActionButton("我想增加手臂维度，怎么练？")
            }
            .padding(.top, 8)
        }
        .padding(.vertical, 40)
    }
    
    private func quickActionButton(_ text: String) -> some View {
        Button(action: {
            onSendMessage?(text)
        }) {
            HStack {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black)
            .cornerRadius(12)
        }
        .padding(.horizontal, 24)
    }
    
    private var streamingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            aiAvatar
            
            VStack(alignment: .leading, spacing: 8) {
                // Streaming Reasoning (Thinking)
                if !aiService.currentStreamingReasoning.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            ProgressView()
                                .controlSize(.mini)
                                .tint(.gray)
                            Text("思考中...")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        Text(aiService.currentStreamingReasoning)
                            .font(.system(size: 13))
                            .foregroundColor(.gray.opacity(0.8))
                            .padding(.leading, 4)
                            .lineLimit(nil)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.03))
                    .cornerRadius(12)
                } else if aiService.currentStreamingText.isEmpty {
                    // Just starting, show dots
                    LoadingDotsView()
                        .padding(.vertical, 4)
                }
                
                // Streaming Content
                if !aiService.currentStreamingText.isEmpty {
                    Markdown(aiService.currentStreamingText)
                        .markdownTheme(.chatDark)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black)
            .cornerRadius(16, corners: [.topRight, .bottomLeft, .bottomRight])
            .textSelection(.enabled)
            
            Spacer(minLength: 40)
        }
    }
    
    
    private var aiAvatar: some View {
        ZStack {
            Circle()
                .fill(AppColors.blue.opacity(0.2))
                .frame(width: 40, height: 40)
            Image(systemName: "sparkle")
                .font(.system(size: 18))
                .foregroundColor(AppColors.blue)
        }
    }
    
    /// 始终将滚动位置保持在最新一条「可见消息」或正在流式输出的位置
    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeOut(duration: 0.2)) {
                // 优先滚到正在流式输出的气泡
                if aiService.isLoading {
                    proxy.scrollTo("streaming", anchor: .bottom)
                    return
                }
                
                // 只在最后一条「用户/助手」消息上滚动，忽略 tool 等内部消息
                if let lastVisible = aiService.conversationHistory.last(where: {
                    $0.role == "user" || $0.role == "assistant"
                }) {
                    proxy.scrollTo(lastVisible.id, anchor: .bottom)
                }
            }
        }
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatMessage
    var additionalMessages: [ChatMessage] = []
    /// Option 1: Legacy tool action (unconfirmed)
    var onShowPlan: (() -> Void)? = nil
    /// Option 2: Show historical confirmed plan
    var onShowConfirmedPlan: ((ConfirmedPlan) -> Void)? = nil
    
    @State private var isReasoningExpanded: Bool = false
    var isUser: Bool { message.role == "user" }
    
    private var hasJsonBlock: Bool {
        message.role == "assistant" && (message.content ?? "").contains("```json")
    }
    
    private struct ToolActionLink: Identifiable {
        let id: String
        let name: String
        let isDelete: Bool
        let isCancelled: Bool
        
        var title: String {
            if isCancelled {
                return isDelete ? "已取消删除方案" : "已取消修改方案"
            }
            return isDelete ? "待确认删除方案" : "待确认修改方案"
        }
    }
    
    private var unconfirmedActionLinks: [ToolActionLink] {
        let allMessagesInBubble = [message] + additionalMessages
        let confirmedIds = Set(allMessagesInBubble.flatMap { $0.confirmedPlans }.map { $0.id })
        
        var links: [ToolActionLink] = []
        for msg in allMessagesInBubble {
            if msg.role == "assistant" {
                let msgCancelled = msg.isCancelled == true
                if let toolCalls = msg.toolCalls {
                    for tc in toolCalls {
                        if !confirmedIds.contains(tc.id) {
                            if tc.name == "delete_training_item" {
                                links.append(ToolActionLink(id: tc.id, name: tc.name, isDelete: true, isCancelled: msgCancelled))
                            } else if tc.name == "execute_training_action" {
                                links.append(ToolActionLink(id: tc.id, name: tc.name, isDelete: false, isCancelled: msgCancelled))
                            }
                        }
                    }
                }
                
                // Legacy JSON block support (if no tool calls match)
                if links.isEmpty && confirmedIds.isEmpty && (msg.content ?? "").contains("```json") {
                    links.append(ToolActionLink(id: msg.id, name: "legacy", isDelete: false, isCancelled: msgCancelled))
                }
            }
        }
        return links
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if isUser {
                Spacer(minLength: 60)
            } else {
                // AI Avatar
                ZStack {
                    Circle()
                        .fill(AppColors.blue.opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: "sparkle")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.blue)
                }
            }
            
            VStack(alignment: .leading, spacing: 10) {
                // 1. Thinking Process (Reasoning)
                if let reasoning = message.reasoning, !reasoning.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: {
                            withAnimation(.spring()) {
                                isReasoningExpanded.toggle()
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: isReasoningExpanded ? "chevron.down.circle.fill" : "chevron.right.circle.fill")
                                    .font(.system(size: 14))
                                Text("思考过程")
                                    .font(.system(size: 13, weight: .bold))
                                Spacer()
                            }
                            .foregroundColor(.gray)
                        }
                        
                        if isReasoningExpanded {
                            Text(reasoning)
                                .font(.system(size: 13))
                                .foregroundColor(.gray.opacity(0.8))
                                .padding(.leading, 8)
                                .padding(.vertical, 4)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                    .padding(10)
                    .background(Color.white.opacity(0.04))
                    .cornerRadius(12)
                    .padding(.bottom, 4)
                }
                
                // 2. Main Content (Combined Group)
                let allMessagesInBubble = [message] + additionalMessages
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(allMessagesInBubble) { msg in
                        if let content = msg.content {
                            let displayContent = msg.role == "assistant" ? stripJsonBlocks(content) : content
                            if !displayContent.isEmpty {
                                VStack(alignment: .leading) {
                                    Markdown(displayContent)
                                        .markdownTheme(.chatDark)
                                }
                                .textSelection(.enabled) // Modifier on internal container to ensure selection
                            }
                        }
                    }
                }
                
                // 3. Training Plan Link (Support both legacy JSON and New Tool)
                
                // 3A. Confirmed Plans stored in Database (The New Way)
                let confirmedPlans = allMessagesInBubble.flatMap { $0.confirmedPlans }
                if !confirmedPlans.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(confirmedPlans) { plan in
                            Button(action: {
                                onShowConfirmedPlan?(plan)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: plan.actionType == "deleteById" ? "trash.fill" : "sparkle")
                                        .font(.system(size: 13))
                                    Text(plan.title)
                                        .font(.system(size: 15, weight: .medium))
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .semibold))
                                }
                                .foregroundColor(plan.actionType == "deleteById" ? .red : AppColors.blue)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 4)
                } 
                // 3B. Unconfirmed Active Tool Links (Multiple)
                let unconfirmed = unconfirmedActionLinks
                if !unconfirmed.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(unconfirmed) { link in
                            Button(action: {
                                onShowPlan?()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: link.isDelete ? "trash.fill" : "sparkle")
                                        .font(.system(size: 13))
                                    Text(link.title)
                                        .font(.system(size: 15, weight: .medium))
                                    if !link.isCancelled {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                    }
                                }
                                .foregroundColor(link.isCancelled ? .gray : (link.isDelete ? .red : AppColors.blue))
                                .padding(.top, 4)
                            }
                            .disabled(link.isCancelled)
                        }
                    }
                }
                
                // 4. Configuration Button
                if message.showSettingsBtn == true {
                    Button(action: {
                        withAnimation {
                            // Use a local way to dismiss the sheet and switch view via manager
                            NotificationCenter.default.post(name: NSNotification.Name("CloseAIChatAndGoToSettings"), object: nil)
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 13))
                            Text("点击去配置 AI 助手")
                                .font(.system(size: 15, weight: .medium))
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .foregroundColor(AppColors.blue)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(AppColors.blue.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 4)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isUser
                    ? AppColors.blue.opacity(0.9)
                    : Color.black
            )
            .cornerRadius(16, corners: isUser
                ? [.topLeft, .bottomLeft, .bottomRight]
                : [.topRight, .bottomLeft, .bottomRight]
            )
            
            if !isUser {
                Spacer(minLength: 40)
            }
        }
    }
    
    private func stripJsonBlocks(_ text: String) -> String {
        var cleaned = text
        if let range = cleaned.range(of: "```json"),
           let endRange = cleaned.range(of: "```", range: range.upperBound..<cleaned.endIndex) {
            cleaned.removeSubrange(range.lowerBound..<endRange.upperBound)
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Corner Radius Extension

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

// MARK: - Helper Components

struct LoadingDotsView: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.gray.opacity(0.8))
                    .frame(width: 7, height: 7)
                    .scaleEffect(isAnimating ? 1.4 : 0.8)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(i) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}
