import AppKit
import ServiceManagement
import SwiftUI
import WebKit

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            AboutSettingsView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 520, height: 430)
        .onAppear {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}

// MARK: - General

private struct GeneralSettingsView: View {
    @State private var launchAtLogin =
        SMAppService.mainApp.status == .enabled

    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section {
                Toggle(
                    "Launch TurboKiller at login",
                    isOn: Binding(
                        get: {
                            launchAtLogin
                        },
                        set: { newValue in
                            updateLaunchAtLogin(newValue)
                        }
                    )
                )

                Text(
                    "Automatically open TurboKiller when you log in to your Mac."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Language") {
                LabeledContent("App language") {
                    Button("Open Language & Region…") {
                        openLanguageSettings()
                    }
                }

                Text(
                    "Under Applications, add or select TurboKiller and choose a language. This changes TurboKiller only and does not change your Mac's system language."
                )
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }

            if let launchAtLoginError {
                Section {
                    Label(
                        launchAtLoginError,
                        systemImage:
                            "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func updateLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }

            launchAtLogin =
                service.status == .enabled

            launchAtLoginError = nil

        } catch {
            launchAtLogin =
                service.status == .enabled

            launchAtLoginError =
                error.localizedDescription
        }
    }

    private func openLanguageSettings() {
        guard let url = URL(
            string:
                "x-apple.systempreferences:com.apple.Localization-Settings.extension"
        ) else {
            return
        }

        NSWorkspace.shared.open(url)
    }
}

// MARK: - About

private struct AboutSettingsView: View {
    @State private var showingSupport = false
    @State private var diagnosticsCopied = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Image(
                    nsImage:
                        NSApplication.shared.applicationIconImage
                )
                .resizable()
                .frame(width: 72, height: 72)

                VStack(spacing: 4) {
                    Text("TurboKiller")
                        .font(.title2.weight(.semibold))

                    Text(versionText)
                        .foregroundStyle(.secondary)

                    Text(
                        "Turbo Boost control for Intel Macs"
                    )
                    .foregroundStyle(.secondary)
                }

                Text("Free and open source · GNU GPL v2")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    Link(
                        destination: URL(
                            string:
                                "https://github.com/hello-nico-chan/turbo-killer"
                        )!
                    ) {
                        Label(
                            "Official Project",
                            systemImage: "checkmark.seal"
                        )
                    }

                    Link(
                        destination: URL(
                            string:
                                "https://github.com/hello-nico-chan/turbo-killer/issues/new"
                        )!
                    ) {
                        Label(
                            "Report an Issue",
                            systemImage: "ladybug"
                        )
                    }
                }

                GroupBox {
                    VStack(spacing: 10) {
                        Label(
                            "Support TurboKiller",
                            systemImage:
                                "cup.and.saucer.fill"
                        )
                        .font(.headline)

                        Text(
                            "TurboKiller is free and open source. If it helps you, you can buy me a coffee."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                        Button {
                            showingSupport = true
                        } label: {
                            Label(
                                "Buy me a coffee",
                                systemImage:
                                    "heart.fill"
                            )
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(
                        maxWidth: .infinity,
                        alignment: .center
                    )
                    .padding(.vertical, 4)
                }

                Divider()

                HStack(spacing: 14) {
                    Link(
                        "NicoTech Studio",
                        destination: URL(
                            string:
                                "https://nicotech.cc"
                        )!
                    )

                    Link(
                        "License",
                        destination: URL(
                            string:
                                "https://github.com/hello-nico-chan/turbo-killer/blob/main/LICENSE"
                        )!
                    )

                    Link(
                        "Third-Party Notices",
                        destination: URL(
                            string:
                                "https://github.com/hello-nico-chan/turbo-killer/blob/main/THIRD_PARTY_NOTICES.md"
                        )!
                    )
                }
                .font(.caption)

                Button {
                    copyDiagnostics()
                } label: {
                    if diagnosticsCopied {
                        Label(
                            "Copied",
                            systemImage: "checkmark"
                        )
                    } else {
                        Label(
                            "Copy Diagnostics",
                            systemImage:
                                "doc.on.doc"
                        )
                    }
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .sheet(isPresented: $showingSupport) {
            KofiSupportView()
        }
    }

    private var versionText: String {
        let version =
            Bundle.main.object(
                forInfoDictionaryKey:
                    "CFBundleShortVersionString"
            ) as? String ?? "—"

        return String(
            format:
                String(localized: "Version %@"),
            version
        )
    }

    private func copyDiagnostics() {
        Task { @MainActor in
            let turboBoostStatus: String

            do {
                switch try await
                    LegacyKextTurboBoostController()
                        .currentStatus()
                {
                case .enabled:
                    turboBoostStatus = "Enabled"

                case .disabled:
                    turboBoostStatus = "Disabled"

                case .unavailable:
                    turboBoostStatus = "Unavailable"
                }
            } catch {
                turboBoostStatus =
                    "Unavailable (\(error.localizedDescription))"
            }

    #if arch(x86_64)
            let architecture = "x86_64"
    #elseif arch(arm64)
            let architecture = "arm64"
    #else
            let architecture = "Unknown"
    #endif

            let version =
                Bundle.main.object(
                    forInfoDictionaryKey:
                        "CFBundleShortVersionString"
                ) as? String ?? "Unknown"

            let build =
                Bundle.main.object(
                    forInfoDictionaryKey:
                        "CFBundleVersion"
                ) as? String ?? "Unknown"

            let bundleIdentifier =
                Bundle.main.bundleIdentifier
                ?? "Unknown"

            let launchAtLoginStatus =
                serviceStatusText(
                    SMAppService.mainApp.status
                )

            let helperStatus =
                serviceStatusText(
                    SMAppService.daemon(
                        plistName:
                            "cc.nicotech.TurboKiller.Helper.plist"
                    ).status
                )

            let osVersion =
                ProcessInfo.processInfo
                    .operatingSystemVersion

            let diagnostics = """
            TurboKiller \(version) (\(build))
            macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)
            Architecture: \(architecture)
            Bundle ID: \(bundleIdentifier)
            App Path: \(Bundle.main.bundleURL.path)
            Locale: \(Locale.current.identifier)
            Launch at Login: \(launchAtLoginStatus)
            Privileged Helper: \(helperStatus)
            Turbo Boost: \(turboBoostStatus)
            Official Project: https://github.com/hello-nico-chan/turbo-killer
            """

            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()

            pasteboard.setString(
                diagnostics + "\n",
                forType: .string
            )

            diagnosticsCopied = true

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 2
            ) {
                diagnosticsCopied = false
            }
        }
    }

    private func serviceStatusText(
        _ status: SMAppService.Status
    ) -> String {
        switch status {
        case .enabled:
            return "Enabled"

        case .requiresApproval:
            return "Requires Approval"

        case .notRegistered:
            return "Not Registered"

        case .notFound:
            return "Not Found"

        @unknown default:
            return "Unknown"
        }
    }
}

// MARK: - Ko-fi

private struct KofiSupportView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Label(
                    "Support TurboKiller",
                    systemImage: "cup.and.saucer.fill"
                )
                .font(.headline)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(
                        systemName:
                            "xmark.circle.fill"
                    )
                    .font(.title3)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            KofiTipPanel()
        }
        .padding(16)
        .frame(width: 520, height: 680)
    }
}

private struct KofiTipPanel: NSViewRepresentable {
    private var url: URL {
        var components = URLComponents(
            string:
                "https://ko-fi.com/hello_nico_chan/?hidefeed=true&widget=true&embed=true&preview=true"
        )!

        var items = components.queryItems ?? []

        items.append(
            URLQueryItem(
                name: "_t",
                value: String(Int(Date().timeIntervalSince1970))
            )
        )

        components.queryItems = items

        return components.url!
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(
        context: Context
    ) -> WKWebView {
        let configuration =
            WKWebViewConfiguration()

        // Keep Ko-fi web data isolated from the app and avoid
        // persisting stale widget state between launches.
        configuration.websiteDataStore =
            .nonPersistent()

        let webView = WKWebView(
            frame: .zero,
            configuration: configuration
        )

        webView.navigationDelegate =
            context.coordinator

        webView.uiDelegate =
            context.coordinator

        webView.allowsLinkPreview = false

        let request = URLRequest(
            url: url,
            cachePolicy:
                .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )

        webView.load(request)

        return webView
    }

    func updateNSView(
        _ nsView: WKWebView,
        context: Context
    ) {
    }

    final class Coordinator:
        NSObject,
        WKNavigationDelegate,
        WKUIDelegate
    {
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration:
                WKWebViewConfiguration,
            for navigationAction:
                WKNavigationAction,
            windowFeatures:
                WKWindowFeatures
        ) -> WKWebView? {
            guard
                navigationAction.targetFrame == nil,
                let url =
                    navigationAction.request.url
            else {
                return nil
            }

            if url.scheme == "http" ||
                url.scheme == "https"
            {
                webView.load(
                    URLRequest(url: url)
                )
            } else {
                NSWorkspace.shared.open(url)
            }

            return nil
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction:
                WKNavigationAction,
            decisionHandler:
                @escaping (
                    WKNavigationActionPolicy
                ) -> Void
        ) {
            guard
                let url =
                    navigationAction.request.url,
                let scheme = url.scheme
            else {
                decisionHandler(.allow)
                return
            }

            if scheme == "http" ||
                scheme == "https" ||
                scheme == "about"
            {
                decisionHandler(.allow)
            } else {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}
