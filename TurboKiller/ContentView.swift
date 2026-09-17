//
//  ContentView.swift
//  TurboKiller
//
//  Created by NicoTech Studio on 2026/9/16.
//

import AppKit
import ServiceManagement
import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var model = TurboKillerModel()
    
    private let helperCodeSigningRequirement =
        #"identifier "TurboKillerHelper" and anchor apple generic and certificate leaf[subject.OU] = "PPXL64QJ2V""#

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "wind")
                    .font(.title2)
                    .foregroundStyle(.tint)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TurboKiller")
                        .font(.headline)

                    Text("Turbo Boost control for Intel Macs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: compatibilityIcon)
                    .foregroundStyle(compatibilityColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(compatibilityTitle)
                        .font(.subheadline.weight(.medium))

                    Text(compatibilityDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: statusIcon)
                    .foregroundStyle(statusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.subheadline.weight(.medium))

                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let requiredAction = model.requiredAction {
                requiredActionView(requiredAction)
            }

            if let errorMessage = model.errorMessage {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)

                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.red.opacity(0.08))
                )
            }

            Button {
                Task {
                    await model.toggleTurboBoost()
                }
            } label: {
                HStack {
                    if model.isBusy {
                        ProgressView()
                            .controlSize(.small)

                        Text("Working…")
                    } else {
                        Image(systemName: toggleIcon)
                        Text(toggleTitle)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(
                model.turboBoostStatus == .unavailable ||
                model.isBusy
            )

            Divider()

            HStack {
                Button("Install Helper") {
                    do {
                        let service = SMAppService.daemon(
                            plistName: "cc.nicotech.TurboKiller.Helper.plist"
                        )

                        try service.register()

                        print("✅ Helper registered")
                    } catch {
                        print("❌ Helper registration failed:", error)
                    }
                }
                
                Spacer()
                
                Button("Ping Helper") {
                    let connection = NSXPCConnection(
                        machServiceName: "cc.nicotech.TurboKiller.Helper",
                        options: .privileged
                    )

                    connection.remoteObjectInterface =
                        NSXPCInterface(
                            with: TurboKillerHelperProtocol.self
                        )
                    
                    connection.setCodeSigningRequirement(
                        helperCodeSigningRequirement
                    )

                    connection.invalidationHandler = {
                        print("ℹ️ Helper connection invalidated")
                    }

                    connection.interruptionHandler = {
                        print("⚠️ Helper connection interrupted")
                    }

                    connection.resume()

                    guard let proxy =
                        connection.remoteObjectProxyWithErrorHandler({ error in
                            print("❌ XPC error:", error)
                            connection.invalidate()
                        }) as? TurboKillerHelperProtocol
                    else {
                        print("❌ Could not create helper proxy")
                        connection.invalidate()
                        return
                    }

                    proxy.ping { message, uid in
                        print("✅ Helper replied:", message)
                        print("✅ Helper UID:", uid)
                        connection.invalidate()
                    }
                }
                
                Spacer()

                Button("Quit TurboKiller") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 340)
        .task {
            await model.refreshStatus()
        }
    }

    // MARK: - Required actions

    @ViewBuilder
    private func requiredActionView(
        _ action: TurboKillerRequiredAction
    ) -> some View {
        switch action {
        case .approveKernelExtension:
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lock.shield.fill")
                        .foregroundStyle(.orange)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Approval required")
                            .font(.caption.weight(.semibold))

                        Text(
                            "macOS blocked the Turbo Boost kernel extension. " +
                            "Open System Settings → Privacy & Security and allow it, " +
                            "then try again."
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button("Open System Settings") {
                    openSystemSettings()
                }
                .controlSize(.small)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.08))
            )

        case .restartRequired:
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "restart.circle.fill")
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 3) {
                    Text("Restart required")
                        .font(.caption.weight(.semibold))

                    Text(
                        "macOS has approved the kernel extension, " +
                        "but your Mac must be restarted once before TurboKiller can use it."
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.orange.opacity(0.08))
            )
        }
    }

    private func openSystemSettings() {
        let settingsURL = URL(
            fileURLWithPath: "/System/Applications/System Settings.app"
        )

        NSWorkspace.shared.open(settingsURL)
    }

    // MARK: - Hardware compatibility

    private var compatibilityIcon: String {
        switch model.hardware {
        case .intelMac:
            "checkmark.circle.fill"

        case .appleSilicon:
            "xmark.circle.fill"
        }
    }

    private var compatibilityColor: Color {
        switch model.hardware {
        case .intelMac:
            .green

        case .appleSilicon:
            .orange
        }
    }

    private var compatibilityTitle: String {
        switch model.hardware {
        case .intelMac:
            "Intel Mac detected"

        case .appleSilicon:
            "Apple silicon detected"
        }
    }

    private var compatibilityDetail: String {
        switch model.hardware {
        case .intelMac:
            "This Mac is compatible with TurboKiller's target platform."

        case .appleSilicon:
            "TurboKiller is designed for Intel Macs only."
        }
    }

    // MARK: - Turbo Boost status

    private var statusIcon: String {
        switch model.turboBoostStatus {
        case .unavailable:
            "questionmark.circle"

        case .enabled:
            "bolt.circle.fill"

        case .disabled:
            "bolt.slash.circle.fill"
        }
    }

    private var statusColor: Color {
        switch model.turboBoostStatus {
        case .unavailable:
            .secondary

        case .enabled:
            .orange

        case .disabled:
            .green
        }
    }

    private var statusTitle: String {
        switch model.turboBoostStatus {
        case .unavailable:
            "Turbo Boost status unavailable"

        case .enabled:
            "Turbo Boost is active"

        case .disabled:
            "Turbo Boost is disabled"
        }
    }

    private var statusDetail: String {
        switch model.turboBoostStatus {
        case .unavailable:
            "Turbo Boost status could not be read."

        case .enabled:
            "Maximum CPU performance is available."

        case .disabled:
            "The CPU is running without Turbo Boost."
        }
    }

    // MARK: - Toggle button

    private var toggleTitle: String {
        model.turboBoostStatus == .disabled
            ? "Restore Turbo Boost"
            : "Kill Turbo Boost"
    }

    private var toggleIcon: String {
        model.turboBoostStatus == .disabled
            ? "bolt.fill"
            : "bolt.slash.fill"
    }
}

#Preview {
    ContentView()
}
