import SwiftUI

struct PrivacyProtocolView: View {
    @Environment(\.dismiss) private var dismiss
    
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
                    
                    Text("隐私政策与用户协议")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                        linkRow(title: "隐私政策", url: "https://www.yuque.com/yuqueyonghu6hjehk/saf1wb/lw3k9gp2pt61pxld")
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                        linkRow(title: "用户协议", url: "https://www.yuque.com/yuqueyonghu6hjehk/saf1wb/uap36kxc04tc7etg")
                        Divider().background(Color.white.opacity(0.1)).padding(.horizontal)
                    }
                    .padding(.top, 20)
                }
            }
        }
    }
    
    private func linkRow(title: String, url: String) -> some View {
        Button(action: {
            if let linkURL = URL(string: url) {
                UIApplication.shared.open(linkURL)
            }
        }) {
            HStack {
                Text(title)
                    .foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal)
            .padding(.vertical, 16)
        }
    }
    
}

#Preview {
    PrivacyProtocolView()
}
