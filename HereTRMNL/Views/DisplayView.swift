import AppKit
import SwiftUI

struct DisplayView: View {
    @EnvironmentObject private var session: DisplaySession
    @EnvironmentObject private var windowChrome: WindowChromeController
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.openSettings) private var openSettings
    @Environment(\.colorScheme) private var colorScheme

    private var shouldInvertImage: Bool {
        switch settings.displayTone {
        case .automatic:
            return colorScheme == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }

    /// E-ink letterbox only when a screen is shown; empty/error use system window chrome.
    private var canvasBackground: Color {
        guard session.image != nil else {
            return Color(nsColor: .windowBackgroundColor)
        }
        return shouldInvertImage ? .white : .black
    }

    private var windowBackdropColor: NSColor {
        guard session.image != nil else {
            return .windowBackgroundColor
        }
        return shouldInvertImage ? .white : .black
    }

    var body: some View {
        Group {
            if case .failed(let message) = session.phase, !settings.isConfigured {
                ContentUnavailableView {
                    Label("Set Up Connection", systemImage: "display")
                } description: {
                    Text(message)
                } actions: {
                    Button("Open Settings") {
                        openSettings()
                    }
                }
            } else if case .failed(let message) = session.phase {
                ContentUnavailableView {
                    Label("Unable to Load Display", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") {
                        Task { await session.refresh(manual: true) }
                    }
                }
            } else if let image = session.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .modifier(DisplayToneModifier(invert: shouldInvertImage))
                    .accessibilityLabel(session.filename ?? String(localized: "Display image"))
            } else if settings.isConfigured || session.phase == .loading {
                ProgressView()
            } else {
                ContentUnavailableView {
                    Label("Waiting for Display", systemImage: "display")
                } description: {
                    Text("Connect a LaraPaper server in Settings to show the next screen.")
                } actions: {
                    Button("Open Settings") {
                        openSettings()
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(canvasBackground)
        .background(WindowChromeInstaller(controller: windowChrome))
        .ignoresSafeArea()
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .task {
            syncAspectRatio()
            syncWindowPreferences()
        }
        .onChange(of: settings.windowOpacity) { _, _ in
            syncWindowPreferences()
        }
        .onChange(of: settings.hideToolbarInFullScreen) { _, _ in
            syncWindowPreferences()
        }
        .onChange(of: settings.displayTone) { _, _ in
            syncWindowPreferences()
        }
        .onChange(of: colorScheme) { _, _ in
            syncWindowPreferences()
        }
        .onChange(of: session.deviceContentSize) { _, size in
            if let size {
                windowChrome.lockAspect(to: NSSize(width: size.width, height: size.height))
            }
        }
        .onChange(of: session.image) { _, image in
            syncWindowPreferences()
            if let image {
                windowChrome.lockAspect(to: image)
            }
        }
        .toolbar {
            ToolbarSpacer(.flexible)

            ToolbarItemGroup(placement: .confirmationAction) {
                Button(
                    windowChrome.isPinned ? "Unpin" : "Pin",
                    systemImage: windowChrome.isPinned ? "pin.fill" : "pin"
                ) {
                    windowChrome.isPinned.toggle()
                }

                Button("Standard Size", systemImage: "rectangle.center.inset.filled") {
                    windowChrome.restoreStandardSize()
                }
                .help("Restore the window to the device screen size")

                Button {
                    Task { await session.refresh(manual: true) }
                } label: {
                    if session.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(!settings.isConfigured || session.isRefreshing)
                .help("Refresh")
            }
        }
    }

    private func syncAspectRatio() {
        if let size = session.deviceContentSize {
            windowChrome.lockAspect(to: NSSize(width: size.width, height: size.height))
        } else if let image = session.image {
            windowChrome.lockAspect(to: image)
        } else {
            windowChrome.lockAspect(to: WindowChromeController.defaultContentSize)
        }
    }

    private func syncWindowPreferences() {
        windowChrome.applyDisplayPreferences(
            opacity: settings.windowOpacity,
            hideToolbarInFullScreen: settings.hideToolbarInFullScreen,
            backdropColor: windowBackdropColor
        )
    }
}

private struct DisplayToneModifier: ViewModifier {
    let invert: Bool

    func body(content: Content) -> some View {
        if invert {
            content.colorInvert()
        } else {
            content
        }
    }
}
