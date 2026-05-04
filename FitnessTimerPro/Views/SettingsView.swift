import SwiftUI
import PhotosUI

// MARK: - UserDefaults Keys for Exercise Defaults
struct ExerciseDefaults {
    private static let setsKey = "exerciseDefaultSets"
    private static let trainingMinKey = "exerciseDefaultTrainingMin"
    private static let trainingSecKey = "exerciseDefaultTrainingSec"
    private static let restMinKey = "exerciseDefaultRestMin"
    private static let restSecKey = "exerciseDefaultRestSec"
    private static let isUnlimitedKey = "exerciseDefaultIsUnlimited"
    
    static var sets: Int {
        get {
            let val = UserDefaults.standard.integer(forKey: setsKey)
            return val == 0 ? 4 : val
        }
        set { UserDefaults.standard.set(newValue, forKey: setsKey) }
    }
    
    static var trainingMin: Int {
        get {
            let val = UserDefaults.standard.object(forKey: trainingMinKey) as? Int
            return val ?? 1
        }
        set { UserDefaults.standard.set(newValue, forKey: trainingMinKey) }
    }
    
    static var trainingSec: Int {
        get { UserDefaults.standard.integer(forKey: trainingSecKey) }
        set { UserDefaults.standard.set(newValue, forKey: trainingSecKey) }
    }
    
    static var restMin: Int {
        get {
            let val = UserDefaults.standard.object(forKey: restMinKey) as? Int
            return val ?? 1
        }
        set { UserDefaults.standard.set(newValue, forKey: restMinKey) }
    }
    
    static var restSec: Int {
        get { UserDefaults.standard.integer(forKey: restSecKey) }
        set { UserDefaults.standard.set(newValue, forKey: restSecKey) }
    }
    
    static var isUnlimited: Bool {
        get { UserDefaults.standard.bool(forKey: isUnlimitedKey) }
        set { UserDefaults.standard.set(newValue, forKey: isUnlimitedKey) }
    }
}

// MARK: - Enable swipe back when nav bar is hidden
struct EnableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.isUserInteractionEnabled = false
        return vc
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            uiViewController.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            uiViewController.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
    }
}

// MARK: - Settings Page Destination
enum SettingsDestination: Hashable {
    case defaults
    case feedback
    case fontSelection
    case aiSettings
    case privacy
}

// MARK: - Settings View
struct SettingsView: View {
    @EnvironmentObject var manager: WorkoutManager
    @AppStorage("isAICreatorEnabled") private var isAICreatorEnabled = true
    
    var body: some View {
        NavigationStack(path: $manager.settingsPath) {
            settingsMainView
                .navigationBarHidden(true)
                .navigationDestination(for: SettingsDestination.self) { destination in
                    switch destination {
                    case .defaults:
                        DefaultValuesView()
                            .navigationBarHidden(true)
                            .background(EnableSwipeBack())
                    case .feedback:
                        FeedbackView()
                            .navigationBarHidden(true)
                            .background(EnableSwipeBack())
                    case .fontSelection:
                        FontSelectionView()
                            .navigationBarHidden(true)
                            .background(EnableSwipeBack())
                    case .aiSettings:
                        AISettingsView()
                            .navigationBarHidden(true)
                            .background(EnableSwipeBack())
                    case .privacy:
                        PrivacyProtocolView()
                            .navigationBarHidden(true)
                            .background(EnableSwipeBack())
                    }
                }
        }
    }
    
    private var settingsMainView: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Simple list with top padding
                VStack(spacing: 0) {
                    Spacer().frame(height: 20)
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                    Button(action: { manager.settingsPath.append(.defaults) }) {
                        HStack {
                            Text("添加训练计划默认值")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                    
                    Button(action: { manager.settingsPath.append(.fontSelection) }) {
                        HStack {
                            Text("计时器字体")
                                .foregroundColor(.white)
                            Spacer()
                            Text({
                                if manager.timerFontName == "BebasNeue-Regular" { return "BebasNeue (默认)" }
                                if manager.timerFontName == "Oswald-Regular" { return "Oswald" }
                                return manager.timerFontName
                            }())
                                .foregroundColor(.gray)
                                .font(.body)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                    
                    Toggle(isOn: $isAICreatorEnabled) {
                        Text("AI 规划助手")
                            .foregroundColor(.white)
                    }
                    .tint(AppColors.green)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                    
                    Button(action: { manager.settingsPath.append(.aiSettings) }) {
                        HStack {
                            Text("AI 规划助手管理")
                                .foregroundColor(.white)
                            Spacer()
                            let provider = AIService.shared.currentProvider
                            Text(provider.rawValue)
                                .foregroundColor(.gray)
                                .font(.body)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                                        
                    Button(action: { manager.settingsPath.append(.privacy) }) {
                        HStack {
                            Text("隐私政策与用户协议")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                    
                    Button(action: { manager.settingsPath.append(.feedback) }) {
                        HStack {
                            Text("联系我们")
                                .foregroundColor(.white)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 16)
                    }
                    
                    Divider().background(Color.white.opacity(0.1)).padding(.horizontal)

                }
                
                Spacer()
            }
        }
    }
}

// MARK: - Default Values View
struct DefaultValuesView: View {
    @EnvironmentObject var manager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var sets: String = ""
    @State private var trainingMin: Int = 1
    @State private var trainingSec: Int = 0
    @State private var restMin: Int = 1
    @State private var restSec: Int = 0
    @State private var isUnlimited: Bool = false
    @State private var isInitialized: Bool = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Custom header with back button and centered title
                ZStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(8) // Add some padding for better hit area
                        }
                        Spacer()
                    }
                    
                    Text("添加训练计划默认值")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Sets
                        VStack(alignment: .leading, spacing: 10) {
                            Text("组数")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            TextField("4", text: $sets)
                                .keyboardType(.numberPad)
                                .padding()
                                .background(AppColors.darkGray)
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                        }
                        
                        // Training Time
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("训练时间")
                                    .font(.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)
                                Spacer()
                                Button(action: { isUnlimited.toggle() }) {
                                    Text("不限时")
                                        .font(.system(size: 14, weight: .black))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(isUnlimited ? AppColors.green : AppColors.darkGray)
                                        .foregroundColor(isUnlimited ? .white : .gray)
                                        .cornerRadius(6)
                                }
                            }
                            
                            ZStack {
                                TimePickerView(minutes: $trainingMin, seconds: $trainingSec)
                                    .opacity(isUnlimited ? 0 : 1)
                                
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(AppColors.darkGray)
                                    .frame(height: 100)
                                    .overlay(
                                        Text("不限时")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 14))
                                    )
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.1)))
                                    .opacity(isUnlimited ? 1 : 0)
                            }
                        }
                        
                        // Rest Time
                        VStack(alignment: .leading, spacing: 8) {
                            Text("休息时间")
                                .font(.body)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)
                            TimePickerView(minutes: $restMin, seconds: $restSec)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                }
            }
            
            // Toast
            VStack {
                if let toast = manager.toastMessage {
                    ToastView(message: toast, style: manager.toastStyle, bottomPadding: 80)
                }
            }
        }
        .onAppear(perform: loadDefaults)
        .onChange(of: sets) { _, _ in 
            autoSave()
            if isInitialized { manager.showToast("已保存", style: .success) }
        }
        .onChange(of: trainingMin) { _, _ in 
            autoSave()
            if isInitialized { manager.showToast("已保存", style: .success) }
        }
        .onChange(of: trainingSec) { _, _ in 
            autoSave()
            if isInitialized { manager.showToast("已保存", style: .success) }
        }
        .onChange(of: restMin) { _, _ in 
            autoSave()
            if isInitialized { manager.showToast("已保存", style: .success) }
        }
        .onChange(of: restSec) { _, _ in 
            autoSave()
            if isInitialized { manager.showToast("已保存", style: .success) }
        }
        .onChange(of: isUnlimited) { _, _ in 
            autoSave()
            if isInitialized { manager.showToast("已保存", style: .success) }
        }
    }
    
    private func loadDefaults() {
        sets = String(ExerciseDefaults.sets)
        trainingMin = ExerciseDefaults.trainingMin
        trainingSec = ExerciseDefaults.trainingSec
        restMin = ExerciseDefaults.restMin
        restSec = ExerciseDefaults.restSec
        isUnlimited = ExerciseDefaults.isUnlimited
        
        // Use delay to prevent toast on initial load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isInitialized = true
        }
    }
    
    private func autoSave() {
        ExerciseDefaults.sets = Int(sets) ?? 4
        ExerciseDefaults.trainingMin = trainingMin
        ExerciseDefaults.trainingSec = trainingSec
        ExerciseDefaults.restMin = restMin
        ExerciseDefaults.restSec = restSec
        ExerciseDefaults.isUnlimited = isUnlimited
    }
}

// MARK: - Feedback View
struct FeedbackView: View {
    @EnvironmentObject var manager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    private let xiaohongshuId = "HankHuang"
    private let douyinId = "85449011809"
    private let emailAddress = "hank1024@qq.com"
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                // Header
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
                    
                    Text("联系我们")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Intro
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppColors.blue.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                
                                Image(systemName: "message.and.waveform.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(AppColors.blue)
                            }
                            
                            VStack(spacing: 8) {
                                Text("期待你的声音")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                
                                Text("一起分享健身，和提供反馈建议，让我们一起把「健身计时器」做得更好。")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 32)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.top, 40)
                        
                        // Contact cards
                        VStack(spacing: 12) {
                            contactCard(
                                icon: "doc.richtext",
                                platform: "小红书",
                                accountId: xiaohongshuId,
                                color: Color.red,
                                url: "https://www.xiaohongshu.com/user/profile/5f77ef370000000001008a3a?xhsshare=userQrCode"
                            )
                            
                            contactCard(
                                icon: "play.rectangle.fill",
                                platform: "抖音",
                                accountId: douyinId,
                                color: Color(red: 0.0, green: 0.82, blue: 0.87),
                                url: "https://v.douyin.com/HBm9N-So5Co/"
                            )
                            
                            contactCard(
                                icon: "envelope.fill",
                                platform: "邮箱",
                                accountId: emailAddress,
                                color: AppColors.blue,
                                url: "mailto:\(emailAddress)"
                            )
                        }
                        .padding(.horizontal)
                        
                        // Tip
                        HStack(spacing: 6) {
                            Image(systemName: "hand.tap.fill")
                                .font(.system(size: 13))
                                .foregroundColor(AppColors.blue.opacity(0.8))
                            Text("点击即可跳转或发送邮件")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 40)
                }
            }
            
            // Toast
            VStack {
                if let toast = manager.toastMessage {
                    ToastView(message: toast, style: manager.toastStyle, bottomPadding: 80)
                }
            }
        }
    }
    
    private func contactCard(icon: String, platform: String, accountId: String, color: Color, url: String) -> some View {
        Button(action: {
            if let linkURL = URL(string: url) {
                UIApplication.shared.open(linkURL)
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(platform)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                    Text(accountId)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                Image(systemName: url.hasPrefix("mailto") ? "envelope.open" : "arrow.up.right")
                    .font(.system(size: 15))
                    .foregroundColor(.gray.opacity(0.6))
            }
            .padding(16)
            .background(AppColors.darkGray)
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }
}


// MARK: - Font Selection View
struct FontSelectionView: View {
    @EnvironmentObject var manager: WorkoutManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom header with back button and centered title
            ZStack {
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.title3)
                            .foregroundColor(.white)
                            .padding(8) // Add some padding for better hit area
                    }
                    Spacer()
                }
                
                Text("计时器字体")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal)
            .padding(.top, 20)
            .padding(.bottom, 10)
            .background(Color.black)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(manager.availableFonts, id: \.self) { fontName in
                        Button(action: {
                            manager.timerFontName = fontName
                        }) {
                            VStack(spacing: 0) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        let displayName: String = {
                                            if fontName == "BebasNeue-Regular" { return "BebasNeue (默认)" }
                                            if fontName == "Oswald-Regular" { return "Oswald" }
                                            return fontName
                                        }()
                                        Text(displayName)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                        
                                        // Preview
                                        Text("01:30")
                                            .font({
                                                if fontName == "SF Pro" {
                                                    return .system(size: 24, weight: .bold, design: .default)
                                                } else if fontName == "SF Compact" {
                                                    return .system(size: 24, weight: .bold, design: .default).width(.condensed)
                                                } else if fontName == "SF Mono" {
                                                    return .system(size: 24, weight: .bold, design: .monospaced)
                                                } else if fontName == "SF Rounded" {
                                                    return .system(size: 24, weight: .bold, design: .rounded)
                                                } else {
                                                    return .custom(fontName, size: 24)
                                                }
                                            }())
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Spacer()
                                    
                                    if manager.timerFontName == fontName {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 16)
                                .background(Color.white.opacity(manager.timerFontName == fontName ? 0.05 : 0))
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                    .padding(.horizontal)
                            }
                        }
                    }
                }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
