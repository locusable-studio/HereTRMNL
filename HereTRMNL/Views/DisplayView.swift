import AppKit
import SwiftUI

struct DisplayView: View {
    @EnvironmentObject private var session: DisplaySession
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack {
            Color.black

            if let image = session.image {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                placeholder
            }
        }
        .overlay(alignment: .bottom) {
            statusBar
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    Task { await session.refresh(manual: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(!settings.isConfigured)

                Button {
                    openSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
    }

    @ViewBuilder
    private var placeholder: some View {
        VStack(spacing: 12) {
            switch session.phase {
            case .loading:
                ProgressView("Loading display…")
            case .failed(let message):
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.yellow)
                Text(message)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 360)
                if !settings.isConfigured {
                    Button("Open Settings") { openSettings() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Retry") {
                        Task { await session.refresh(manual: true) }
                    }
                }
            default:
                Image(systemName: "display")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                Text("Waiting for display content")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var statusBar: some View {
        HStack(spacing: 12) {
            statusLabel
            Spacer()
            if let filename = session.filename {
                Text(filename)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            if let rate = session.lastRefreshRateSeconds {
                Text("\(rate)s")
            }
        }
        .font(.caption.monospaced())
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.45))
    }

    private var statusLabel: some View {
        Group {
            switch session.phase {
            case .idle:
                Text("Idle")
            case .loading:
                Text("Loading…")
            case .ready:
                if let updated = session.lastUpdated {
                    Text("Updated \(updated, style: .relative) ago")
                } else {
                    Text("Ready")
                }
            case .failed:
                Text("Error")
                    .foregroundStyle(.yellow)
            }
        }
    }
}
