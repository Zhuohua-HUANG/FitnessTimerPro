import SwiftUI

enum DialogContentStyle {
    case scrollable // 只有隐私弹窗用格式a
    case standard   // 其他都用格式b
}

struct StandardDialog: View {
    let title: String
    var message: String? = nil
    var isMessageEnabled: Bool = true
    var contentStyle: DialogContentStyle = .standard
    
    let primaryTitle: String
    var primaryIsWhite: Bool = false
    let primaryAction: () -> Void
    
    var secondaryTitle: String? = nil
    var secondaryAction: (() -> Void)? = nil
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8).ignoresSafeArea()
            
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    if isMessageEnabled, let message = message {
                        switch contentStyle {
                        case .scrollable:
                            ScrollView {
                                Text(LocalizedStringKey(message))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .lineSpacing(6)
                                    .accentColor(.blue)
                                    .padding(.horizontal, 20)
                            }
                            .frame(maxHeight: 100)
                        case .standard:
                            Text(LocalizedStringKey(message))
                                .font(.callout)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.leading)
                                .frame(alignment: .leading)
                        }
                    }
                }
                .padding(.top, 2)
                
                HStack(spacing: 16) {
                    if let secondaryTitle = secondaryTitle, let secondaryAction = secondaryAction {
                        Button(action: secondaryAction) {
                            Text(secondaryTitle)
                                // .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(12)
                        }
                    }
                    
                    Button(action: primaryAction) {
                        Text(primaryTitle)
                            // .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(primaryIsWhite ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(primaryIsWhite ? Color.white : Color.white.opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.top, 2)
            }
            .padding(24)
            .background(Color(hex: "1A1A1A"))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .frame(maxWidth: 320)
            .padding(.horizontal, 40)
        }
    }
}
