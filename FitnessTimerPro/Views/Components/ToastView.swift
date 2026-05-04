import SwiftUI

struct ToastView: View {
    let message: String
    let style: ToastStyle
    let bottomPadding: CGFloat
    
    private var backgroundColor: Color {
        switch style {
        case .info:
            return Color(white: 0.2)
        case .success:
            return AppColors.green.opacity(0.9)
        case .error:
            return Color.red.opacity(0.8)
        }
    }
    
    var body: some View {
        VStack {
            Spacer()
            Text(message)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(backgroundColor)
                .cornerRadius(20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .padding(.bottom, bottomPadding)
        }
    }
}
