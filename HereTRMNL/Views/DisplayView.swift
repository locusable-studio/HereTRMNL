import AppKit
import SwiftUI

struct DisplayView: View {
    @EnvironmentObject private var session: DisplaySession
    @EnvironmentObject private var windowChrome: WindowChromeController
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Group {
            if let image = session.image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityLabel(session.filename ?? String(localized: "Display image"))
            } else if case .loading = session.phase {
                ProgressView()
            } else if case .failed(let message) = session.phase, !settings.isConfigured {
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
        .background(WindowChromeInstaller(controller: windowChrome))
        .ignoresSafeArea()
        .toolbarBackgroundVisibility(.hidden, for: .windowToolbar)
        .onAppear {
            if let image = session.image {
                windowChrome.lockAspect(to: image)
            } else {
                windowChrome.lockAspect(to: WindowChromeController.defaultContentSize)
            }
        }
        .onChange(of: session.image) { _, image in
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

                Button("Refresh", systemImage: "arrow.clockwise") {
                    Task { await session.refresh(manual: true) }
                }
                .disabled(!settings.isConfigured || session.phase == .loading)
            }
        }
    }
}
