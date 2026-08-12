import AppKit
import SwiftUI

struct AboutView: View {
    private static let repositoryURL = URL(
        string: "https://github.com/locusable-studio/HereTRMNL"
    )!
    private static let sparkleURL = URL(
        string: "https://github.com/sparkle-project/Sparkle"
    )!

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("HereTRMNL")
                            .font(.title2.weight(.semibold))
                        Text("LaraPaper desktop display for macOS")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 4)
            }

            Section("Version info") {
                LabeledContent("Version") {
                    Text(versionLabel)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                LabeledContent("Channel") {
                    Text(UpdateChannel.displayName)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Links") {
                linkRow(
                    title: String(localized: "GitHub Repository"),
                    detail: "locusable-studio/HereTRMNL",
                    url: Self.repositoryURL
                )
            }

            Section("Third-party dependencies") {
                linkRow(
                    title: "Sparkle",
                    detail: String(localized: "Software update framework"),
                    url: Self.sparkleURL
                )
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 390)
    }

    private var versionLabel: String {
        let version = Bundle.main.releaseVersionNumber ?? "—"
        let build = Bundle.main.buildVersionNumber ?? "—"
        return "\(version) (\(build))"
    }

    private func linkRow(title: String, detail: String, url: URL) -> some View {
        Button {
            NSWorkspace.shared.open(url)
        } label: {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .foregroundStyle(.primary)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
