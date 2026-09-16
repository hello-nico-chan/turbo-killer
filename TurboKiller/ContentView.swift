//
//  ContentView.swift
//  TurboKiller
//
//  Created by NicoTech Studio on 2026/9/16.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @StateObject private var model = TurboKillerModel()

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
                Image(systemName: "questionmark.circle")
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.subheadline.weight(.medium))
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                Task {
                    await model.toggleTurboBoost()
                }
            } label: {
                Label(toggleTitle, systemImage: toggleIcon)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.turboBoostStatus == .unavailable)

            Divider()

            HStack {
                Text("UI prototype")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

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

    private var compatibilityIcon: String {
        switch model.hardware {
        case .intelMac: "checkmark.circle.fill"
        case .appleSilicon: "xmark.circle.fill"
        }
    }

    private var compatibilityColor: Color {
        switch model.hardware {
        case .intelMac: .green
        case .appleSilicon: .orange
        }
    }

    private var compatibilityTitle: String {
        switch model.hardware {
        case .intelMac: "Intel Mac detected"
        case .appleSilicon: "Apple silicon detected"
        }
    }

    private var compatibilityDetail: String {
        switch model.hardware {
        case .intelMac: "This Mac is compatible with TurboKiller's target platform."
        case .appleSilicon: "TurboKiller is designed for Intel Macs only."
        }
    }

    private var statusTitle: String {
        switch model.turboBoostStatus {
        case .unavailable: "Turbo Boost status unavailable"
        case .enabled: "Turbo Boost is active"
        case .disabled: "Turbo Boost is disabled"
        }
    }

    private var statusDetail: String {
        switch model.turboBoostStatus {
        case .unavailable: "Hardware control is not connected yet."
        case .enabled: "Maximum CPU performance is available."
        case .disabled: "The CPU is running without Turbo Boost."
        }
    }

    private var toggleTitle: String {
        model.turboBoostStatus == .disabled ? "Restore Turbo Boost" : "Kill Turbo Boost"
    }

    private var toggleIcon: String {
        model.turboBoostStatus == .disabled ? "bolt.fill" : "bolt.slash.fill"
    }
}

#Preview {
    ContentView()
}
