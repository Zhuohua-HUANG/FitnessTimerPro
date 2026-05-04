import SwiftUI

// MARK: - AI Settings View (API Key configuration)

private struct HeaderItem: Identifiable {
    let id: UUID
    var key: String
    var value: String
    init(id: UUID = UUID(), key: String = "", value: String = "") {
        self.id = id; self.key = key; self.value = value
    }
}

struct AISettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var manager: WorkoutManager
    @ObservedObject var aiService = AIService.shared

    @State private var selectedProvider: AIProvider = .openai
    @State private var apiKey: String = ""
    @State private var modelName: String = ""
    @State private var customURL: String = ""
    @State private var customHeaders: [String: String] = [:]
    @State private var headerItems: [HeaderItem] = []

    @State private var showClearConfirm = false
    @State private var showHttpWarning = false // HTTP 风险警告
    @State private var pendingHttpData: (url: String, model: String, headers: [String: String])?
    @State private var isInitialized = false
    @State private var isBaseURLExpanded = false
    @FocusState private var urlFieldFocused: Bool

    // curl 解析弹窗
    @State private var showCurlSheet = false
    @State private var curlInput: String = ""

    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
                .contentShape(Rectangle())
                .onTapGesture {
                    // 点击背景收起键盘（取消焦点）
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }

            VStack(spacing: 0) {
                // Custom header with back button and centered title
                ZStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8)
                        }
                        Spacer()
                    }

                    Text("AI 规划助手管理")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {

                        // 1. Provider Selection
                        VStack(alignment: .leading, spacing: 10) {
                            Text("选择服务商")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            Menu {
                                ForEach(AIProvider.allCases) { provider in
                                    Button(action: { selectedProvider = provider }) {
                                        HStack {
                                            Text(provider.rawValue)
                                            if selectedProvider == provider {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedProvider.rawValue)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(AppColors.darkGray)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                            }
                        }

                        // 1b. cURL 一键解析（仅自定义 provider）
                        if selectedProvider == .custom {
                            Button(action: { showCurlSheet = true }) {
                                HStack(spacing: 10) {
                                    Image(systemName: "terminal.fill")
                                        .font(.system(size: 15))
                                    Text("粘贴 cURL 一键导入配置")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 48)
                                .background(Color.white.opacity(0.12))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.2)))
                            }
                            .padding(.vertical, 4)
                        }

                        // 2. Base URL (Folded for non-custom providers)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text(selectedProvider == .custom ? "请求地址 (完整 URL)" : "API 基础地址 (Base URL)")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                Spacer()
                                if selectedProvider != .custom {
                                    Button(action: { withAnimation { isBaseURLExpanded.toggle() } }) {
                                        Text(isBaseURLExpanded ? "收起" : "修改")
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppColors.darkGray)
                                            .foregroundColor(.gray)
                                            .cornerRadius(6)
                                    }
                                }
                            }

                            if selectedProvider == .custom || isBaseURLExpanded {
                                HStack {
                                    TextField(
                                        selectedProvider == .custom
                                            ? "https://api.example.com/v1/chat/completions"
                                            : selectedProvider.defaultBaseURL,
                                        text: $customURL
                                    )
                                    .focused($urlFieldFocused)
                                    .font(.system(size: 15, design: .monospaced))

                                    if !customURL.isEmpty {
                                        Button(action: { customURL = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding()
                                .background(AppColors.darkGray)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))

                                if selectedProvider != .custom && !customURL.isEmpty {
                                    Text("当前已覆盖默认地址。清空以恢复默认。")
                                        .font(.caption2)
                                        .foregroundColor(AppColors.green)
                                }
                            }
                        }

                        // 2b. Custom Headers（仅自定义 provider）
                        if selectedProvider == .custom {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("自定义 Headers")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)

                                // Headers 列表（可编辑，自动保存）
                                ForEach($headerItems) { $item in
                                    HStack(spacing: 8) {
                                        TextField("Header 名称", text: $item.key)
                                            .font(.system(size: 13, design: .monospaced))
                                            .frame(maxWidth: .infinity)
                                            .onChange(of: item.key) { _ in saveHeaderItems() }
                                        Text(":")
                                            .foregroundColor(.gray)
                                        TextField("值", text: $item.value)
                                            .font(.system(size: 13, design: .monospaced))
                                            .frame(maxWidth: .infinity)
                                            .onChange(of: item.value) { _ in saveHeaderItems() }
                                        Button(action: {
                                            headerItems.removeAll { $0.id == item.id }
                                            saveHeaderItems()
                                        }) {
                                            Image(systemName: "minus.circle.fill")
                                                .foregroundColor(.red.opacity(0.7))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(AppColors.darkGray)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.08)))
                                }

                                // 添加新行
                                Button(action: {
                                    headerItems.append(HeaderItem())
                                }) {
                                    HStack {
                                        Image(systemName: "plus.circle.fill")
                                        Text("添加 Header")
                                    }
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                        }

                        // 3. API Key（自定义 provider 隐藏，鉴权通过 Headers 管理）
                        if selectedProvider != .custom {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("API Key")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)

                                HStack {
                                    SecureField("输入 API Key", text: $apiKey)
                                        .font(.system(size: 15, design: .monospaced))

                                    if !apiKey.isEmpty {
                                        Button(action: { apiKey = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding()
                                .background(AppColors.darkGray)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                            }
                        }

                        // 4. Model ID
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("模型型号 (Model ID)")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                Spacer()
                                if selectedProvider != .custom {
                                    Text("默认: \(selectedProvider.defaultModel)")
                                        .font(.caption2)
                                        .foregroundColor(.gray.opacity(0.5))
                                }
                            }

                            HStack {
                                TextField("例如: \(selectedProvider.defaultModel)", text: $modelName)
                                    .font(.system(size: 15, design: .monospaced))

                                if !modelName.isEmpty {
                                    Button(action: { modelName = "" }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(AppColors.darkGray)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                        }

                        // Security Note
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.shield.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("安全说明")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                            }
                            Text("API Key 安全存储在设备 Keychain 中，不会上传到任何服务器。所有 AI 对话直接与模型服务商通信。")
                                .font(.caption)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .padding(.top, 8)

                        // 5. Clear Conversation History
                        VStack(alignment: .leading, spacing: 10) {
                            Text("对话管理")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            Button(action: { showClearConfirm = true }) {
                                Text("清空对话历史")
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 50)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(12)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }

            // Clear Confirmation Dialog
            if showClearConfirm {
                StandardDialog(
                    title: "清空对话历史",
                    message: "确定要清空所有 AI 对话记录吗？此操作不可撤销。",
                    primaryTitle: "确认清空",
                    primaryIsWhite: false,
                    primaryAction: {
                        aiService.clearConversation()
                        showClearConfirm = false
                        manager.showToast("已清空对话记录", style: .success)
                    },
                    secondaryTitle: "取消",
                    secondaryAction: {
                        showClearConfirm = false
                    }
                )
            }

            // HTTP Security Warning Dialog
            if showHttpWarning {
                StandardDialog(
                    title: "⚠️ 安全性风险: HTTP 明文传输",
                    message: "您输入的地址使用 HTTP 协议。这意味着您的 API Key 和内容将以明文传输，极易被窃听或篡改。\n\n是否承担风险继续使用 HTTP 协议？",
                    primaryTitle: "我承担风险",
                    primaryIsWhite: false,
                    primaryAction: {
                        if let data = pendingHttpData {
                            applySettings(url: data.url, model: data.model, headers: data.headers)
                        }
                        showHttpWarning = false
                    },
                    secondaryTitle: "返回修改",
                    secondaryAction: {
                        showHttpWarning = false
                        pendingHttpData = nil
                        // 修复死锁：无论是否确认，只要关闭弹窗就要恢复监听状态
                        isInitialized = true
                    }
                )
            }

            // Global Toast View
            VStack {
                if let toast = manager.toastMessage {
                    ToastView(message: toast, style: manager.toastStyle, bottomPadding: 80)
                }
            }
        }
        .onAppear(perform: loadCurrentSettings)
        .onChange(of: selectedProvider) { _, newValue in
            if isInitialized {
                aiService.currentProvider = newValue
                loadProviderSettings(for: newValue)
                manager.showToast("已保存", style: .success)
            }
        }
        .onChange(of: apiKey) { _, newValue in
            if isInitialized {
                selectedProvider.setAPIKey(newValue)
                manager.showToast("已保存", style: .success)
            }
        }
        .onChange(of: modelName) { _, newValue in
            if isInitialized {
                selectedProvider.setModel(newValue)
                manager.showToast("已保存", style: .success)
            }
        }
        .onChange(of: customURL) { _, newValue in
            if isInitialized {
                let cleaned = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                // HTTPS 地址：自动保存
                if !cleaned.lowercased().hasPrefix("http://") {
                    selectedProvider.setCustomURL(cleaned)
                    if !cleaned.isEmpty {
                        manager.showToast("已保存", style: .success)
                    }
                }
                // HTTP 地址：等失焦后通过 urlFieldFocused.onChange 弹出警告
            }
        }
        .onChange(of: urlFieldFocused) { _, focused in
            // 用 @FocusState 替代已废弃的 onEditingChanged，更可靠地检测失焦
            if !focused && isInitialized {
                let cleaned = customURL.trimmingCharacters(in: .whitespacesAndNewlines)
                if cleaned.lowercased().hasPrefix("http://") && cleaned != selectedProvider.getCustomURL() {
                    pendingHttpData = (cleaned, modelName, customHeaders)
                    showHttpWarning = true
                }
            }
        }
        .sheet(isPresented: $showCurlSheet) {
            CurlImportSheet(
                curlInput: $curlInput,
                onConfirm: { url, model, headers in
                    let finalURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
                    let finalModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // 1. 立即更新 UI 状态，让用户看到解析结果，解决数据“消失”的问题
                    isInitialized = false // 暂时关闭自动保存监听
                    customURL = finalURL
                    modelName = finalModel
                    headerItems = headers.map { HeaderItem(key: $0.key, value: $0.value) }
                    
                    if finalURL.lowercased().hasPrefix("http://") {
                        // 2. HTTP 地址：挂起持久化，准备弹窗
                        pendingHttpData = (finalURL, finalModel, headers)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showHttpWarning = true
                        }
                    } else {
                        // 3. HTTPS 地址：直接持久化
                        applySettings(url: finalURL, model: finalModel, headers: headers)
                    }
                }
            )
        }
    }

    private func applySettings(url: String, model: String, headers: [String: String]) {
        isInitialized = false
        customURL = url
        modelName = model
        customHeaders = headers
        headerItems = headers.map { HeaderItem(key: $0.key, value: $0.value) }

        if !url.isEmpty { AIProvider.custom.setCustomURL(url) }
        if !model.isEmpty { AIProvider.custom.setModel(model) }
        AIProvider.custom.setCustomHeaders(headers)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInitialized = true
            manager.showToast("配置已生效", style: .success)
        }
    }

    // MARK: - Helpers

    private func saveHeaderItems() {
        var dict: [String: String] = [:]
        for item in headerItems {
            let k = item.key.trimmingCharacters(in: .whitespaces)
            let v = item.value.trimmingCharacters(in: .whitespaces)
            if !k.isEmpty { dict[k] = v }
        }
        customHeaders = dict
        AIProvider.custom.setCustomHeaders(dict)
    }

    private func loadCurrentSettings() {
        selectedProvider = aiService.currentProvider
        apiKey = selectedProvider.getAPIKey() ?? ""
        modelName = selectedProvider.getModel()
        customURL = selectedProvider.getCustomURL()
        customHeaders = selectedProvider.getCustomHeaders()
        headerItems = customHeaders.map { HeaderItem(key: $0.key, value: $0.value) }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isInitialized = true
        }
    }

    private func loadProviderSettings(for provider: AIProvider) {
        isInitialized = false

        apiKey = provider.getAPIKey() ?? ""
        modelName = provider.getModel()
        customURL = provider.getCustomURL()
        customHeaders = provider.getCustomHeaders()
        headerItems = customHeaders.map { HeaderItem(key: $0.key, value: $0.value) }
        isBaseURLExpanded = !provider.getCustomURL().isEmpty

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isInitialized = true
        }
    }
}

// MARK: - cURL Import Sheet

struct CurlImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var curlInput: String
    let onConfirm: (String, String, [String: String]) -> Void

    var body: some View {
        NavigationView {
            ZStack {
                AppColors.darkGray.ignoresSafeArea()

                VStack(spacing: 0) {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            // 1. Instructions / Label
                            VStack(alignment: .leading, spacing: 10) {
                                Text("cURL 命令").font(.body).fontWeight(.bold).foregroundColor(.gray)
                                
                                ZStack(alignment: .topTrailing) {
                                    TextEditor(text: $curlInput)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(8)
                                        .scrollContentBackground(.hidden)
                                        .background(Color.black)
                                        .frame(minHeight: 180)
                                        .cornerRadius(12)
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                                    
                                    if !curlInput.isEmpty {
                                        Button(action: { curlInput = "" }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.gray.opacity(0.8))
                                                .font(.system(size: 18))
                                                .padding(12)
                                        }
                                    }
                                }
                                
                                Text("粘贴 cURL 命令，将自动解析 URL、Model 和 Headers。支持 -H, -u, --oauth2-bearer 等参数。")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 4)
                            }

                            // 2. Preview
                            let (previewURL, previewModel, previewHeaders) = parseCurl(curlInput)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("解析预览").font(.body).fontWeight(.bold).foregroundColor(.gray)
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("URL").font(.caption2).fontWeight(.black).foregroundColor(.gray)
                                        Text(previewURL.isEmpty ? "等待输入..." : previewURL)
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(previewURL.isEmpty ? .gray.opacity(0.4) : AppColors.green)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("MODEL").font(.caption2).fontWeight(.black).foregroundColor(.gray)
                                        Text(previewModel.isEmpty ? "等待输入..." : previewModel)
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(previewModel.isEmpty ? .gray.opacity(0.4) : .white)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("HEADERS").font(.caption2).fontWeight(.black).foregroundColor(.gray)
                                        if previewHeaders.isEmpty {
                                            Text("等待中...")
                                                .font(.system(size: 12, design: .monospaced))
                                                .foregroundColor(.gray.opacity(0.4))
                                        } else {
                                            ForEach(previewHeaders.keys.sorted(), id: \.self) { key in
                                                HStack(alignment: .top, spacing: 4) {
                                                    Text("\(key):")
                                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                        .foregroundColor(.gray)
                                                    Text(previewHeaders[key] ?? "")
                                                        .font(.system(size: 12, design: .monospaced))
                                                        .foregroundColor(.white.opacity(0.8))
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.black)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 24)
                    }

                    // Bottom Buttons
                    HStack(spacing: 16) {
                        Button(action: {
                            dismiss()
                        }) {
                            Text("取消")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(hex: "29292D"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        Button(action: {
                            let (url, model, headers) = parseCurl(curlInput)
                            onConfirm(url, model, headers)
                            dismiss()
                        }) {
                            Text("确认导入")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .foregroundColor(.black)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("粘贴 cURL 导入")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
            }
        }
    }

    // MARK: - cURL Parser

    private func parseCurl(_ input: String) -> (url: String, model: String, headers: [String: String]) {
        // 1. 预处理：合并连续行，处理智能引号
        let processed = input
            .replacingOccurrences(of: "\\\r\n", with: " ")
            .replacingOccurrences(of: "\\\n", with: " ")
            .replacingOccurrences(of: "\\\r", with: " ")
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "‘", with: "'")
            .replacingOccurrences(of: "’", with: "'")

        // 2. 健壮的状态机分词器
        var tokens: [String] = []
        let chars = Array(processed)
        var idx = 0
        
        while idx < chars.count {
            // 跳过空白
            while idx < chars.count && chars[idx].isWhitespace { idx += 1 }
            if idx >= chars.count { break }
            
            var currentToken = ""
            var inSingleQuote = false
            var inDoubleQuote = false
            var isEscaped = false
            
            while idx < chars.count {
                let c = chars[idx]
                
                if isEscaped {
                    currentToken.append(c)
                    isEscaped = false
                } else if inSingleQuote {
                    if c == "'" {
                        inSingleQuote = false
                    } else {
                        currentToken.append(c)
                    }
                } else if inDoubleQuote {
                    if c == "\"" {
                        inDoubleQuote = false
                    } else if c == "\\" {
                        isEscaped = true
                    } else {
                        currentToken.append(c)
                    }
                } else {
                    if c == "'" {
                        inSingleQuote = true
                    } else if c == "\"" {
                        inDoubleQuote = true
                    } else if c == "\\" {
                        isEscaped = true
                    } else if c.isWhitespace {
                        break // 分词结束
                    } else {
                        currentToken.append(c)
                    }
                }
                idx += 1
            }
            if !currentToken.isEmpty {
                tokens.append(currentToken)
            }
        }
        
        print("[cURL Parser] Generated Tokens: \(tokens)")

        // 3. 解析 Tokens
        var url = ""
        var model = ""
        var headers: [String: String] = [:]
        var i = 0

        while i < tokens.count {
            let token = tokens[i]
            
            switch token {
            case "curl": break
            case "--location", "-L", "--request", "-X", "--compressed": break
            case "--url":
                i += 1
                if i < tokens.count { url = tokens[i] }
            case "-H", "--header":
                i += 1
                if i < tokens.count {
                    let raw = tokens[i]
                    if let colon = raw.firstIndex(of: ":") {
                        let k = String(raw[raw.startIndex..<colon]).trimmingCharacters(in: .whitespacesAndNewlines)
                        let v = String(raw[raw.index(after: colon)...]).trimmingCharacters(in: .whitespacesAndNewlines)
                        print("  [Header Log] Key: '\(k)', Val: '\(v)'")
                        if !k.isEmpty { headers[k] = v }
                    }
                }
            case "-u", "--user":
                i += 1
                if i < tokens.count {
                    let encoded = Data(tokens[i].utf8).base64EncodedString()
                    headers["Authorization"] = "Basic \(encoded)"
                }
            case "--oauth2-bearer":
                i += 1
                if i < tokens.count {
                    headers["Authorization"] = "Bearer \(tokens[i])"
                }
            case "-d", "--data", "--data-raw", "--data-binary":
                i += 1
                if i < tokens.count {
                    let dataStr = tokens[i].trimmingCharacters(in: .whitespacesAndNewlines)
                    print("  [Data Log] Payload: \(dataStr.prefix(100))...")
                    // 1. JSON 解析
                    if let data = dataStr.data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let m = (json["model"] as? String) ?? (json["model_id"] as? String) {
                            model = m
                        }
                    }
                    // 2. 正则兜底
                    if model.isEmpty {
                        model = extractModelValue(from: dataStr)
                    }
                }
            default:
                // 自动识别 URL
                if url.isEmpty && !token.hasPrefix("-") && (token.hasPrefix("http") || token.contains("://")) {
                    url = token
                }
            }
            i += 1
        }

        let result = (url, model, headers)
        print("[cURL Parser] Final Result - URL: \(url), Model: \(model), Headers: \(headers.count)")
        return result
    }

    private func extractModelValue(from dataStr: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: #""model"\s*:\s*"([^"]+)""#),
              let match = regex.firstMatch(in: dataStr, range: NSRange(dataStr.startIndex..., in: dataStr)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: dataStr) else { return "" }
        return String(dataStr[range])
    }
}
