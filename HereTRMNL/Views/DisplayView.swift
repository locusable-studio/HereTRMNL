import AppKit
import SwiftUI

struct DisplayView: View {
    @EnvironmentObject private var session: DisplaySession
    @EnvironmentObject private var windowChrome: WindowChromeController
    @EnvironmentObject private var settings: AppSettings

    /// E-ink letterbox only when a screen is shown; empty/error use system window chrome.
    private var canvasBackground: Color {
        guard session.image != nil else {
            return Color(nsColor: .windowBackgroundColor)
        }
        return .black
    }

    private var windowBackdropColor: NSColor {
        guard session.image != nil else {
            return .windowBackgroundColor
        }
        return .black
    }

    var body: some View {
        Group {
            if case .failed(let message) = session.phase, !settings.isConfigured {
                ContentUnavailableView {
                    Label("Set Up Connection", systemImage: "display")
                } description: {
                    Text(message)
                } actions: {
                    menuBarHint("Use Connection Settings in the menu bar.")
                }
            } else if let image = session.image {
                // Keep the last frame visible even when a later refresh fails.
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(session.filename ?? String(localized: "Display image"))
            } else if case .failed(let message) = session.phase {
                ContentUnavailableView {
                    Label("Unable to Load Display", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    menuBarHint("Use Refresh Now in the menu bar.")
                }
            } else if settings.isConfigured || session.phase == .loading {
                ProgressView()
            } else {
                ContentUnavailableView {
                    Label("Waiting for Display", systemImage: "display")
                } description: {
                    Text("Connect a LaraPaper server in Connection Settings to show the next screen.")
                } actions: {
                    menuBarHint("Use Connection Settings in the menu bar.")
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(canvasBackground)
        .background(WindowChromeInstaller(controller: windowChrome))
        .ignoresSafeArea()
        .task {
            syncDeviceSize()
            syncWindowPreferences()
        }
        .onChange(of: settings.windowPosition) { _, _ in
            windowChrome.applyPlacement()
        }
        .onChange(of: settings.preferredScreenID) { _, _ in
            windowChrome.applyPlacement()
        }
        .onChange(of: session.deviceContentSize) { _, size in
            if let size {
                windowChrome.setDeviceContentSize(NSSize(width: size.width, height: size.height))
            }
        }
        .onChange(of: session.image) { _, _ in
            syncWindowPreferences()
        }
    }

    /// The window is always click-through, so empty/error states only show a passive
    /// hint; the actual controls live in the menu bar.
    private func menuBarHint(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
    }

    private func syncDeviceSize() {
        if let size = session.deviceContentSize {
            windowChrome.setDeviceContentSize(
                NSSize(width: size.width, height: size.height),
                animated: false
            )
        } else if let image = session.image {
            windowChrome.setDeviceContentSize(from: image, animated: false)
        } else {
            windowChrome.setDeviceContentSize(
                WindowChromeController.defaultContentSize,
                animated: false
            )
        }
    }

    private func syncWindowPreferences() {
        windowChrome.applyDisplayPreferences(
            backdropColor: windowBackdropColor
        )
    }
}
