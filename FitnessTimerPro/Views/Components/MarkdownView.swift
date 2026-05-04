import SwiftUI
import MarkdownUI

// MARK: - Custom Dark Chat Theme for MarkdownUI

extension MarkdownUI.Theme {
    static let chatDark = Theme()
        .text {
            ForegroundColor(.white)
            FontSize(16)
        }
        .strong {
            FontWeight(.bold)
        }
        .emphasis {
            FontStyle(.italic)
        }
        .code {
            FontFamilyVariant(.monospaced)
            FontSize(14)
            ForegroundColor(AppColors.blue)
        }
        .link {
            ForegroundColor(AppColors.blue)
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: 16, bottom: 8)
                .markdownTextStyle {
                    FontSize(22)
                    FontWeight(.bold)
                    ForegroundColor(.white)
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: 12, bottom: 6)
                .markdownTextStyle {
                    FontSize(20)
                    FontWeight(.bold)
                    ForegroundColor(.white)
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: 10, bottom: 4)
                .markdownTextStyle {
                    FontSize(18)
                    FontWeight(.semibold)
                    ForegroundColor(.white)
                }
        }
        .paragraph { configuration in
            configuration.label
                .markdownMargin(top: 0, bottom: 8)
        }
        .listItem { configuration in
            configuration.label
                .markdownMargin(top: 2)
        }
        .codeBlock { configuration in
            ScrollView(.horizontal, showsIndicators: false) {
                configuration.label
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(13)
                        ForegroundColor(.white.opacity(0.9))
                    }
            }
            .padding(12)
            .background(Color.white.opacity(0.08))
            .cornerRadius(8)
            .markdownMargin(top: 8, bottom: 8)
        }
        .table { configuration in
            configuration.label
                .markdownTableBorderStyle(
                    .init(color: .white.opacity(0.15))
                )
                .markdownTableBackgroundStyle(
                    .alternatingRows(Color.clear, Color.white.opacity(0.05))
                )
                .markdownMargin(top: 8, bottom: 8)
        }
        .tableCell { configuration in
            configuration.label
                .markdownTextStyle {
                    FontSize(14)
                    ForegroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
        }
        .blockquote { configuration in
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(AppColors.blue.opacity(0.6))
                    .frame(width: 4)
                configuration.label
                    .markdownTextStyle {
                        ForegroundColor(.white.opacity(0.7))
                        FontSize(15)
                    }
                    .padding(.leading, 12)
            }
            .markdownMargin(top: 8, bottom: 8)
        }
        .thematicBreak {
            Divider()
                .overlay(Color.white.opacity(0.1))
                .markdownMargin(top: 12, bottom: 12)
        }
}
