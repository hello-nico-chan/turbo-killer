//
//  TurboKillerModel.swift
//  TurboKiller
//

import Darwin
import Combine
import Foundation

enum HardwareCompatibility {
    case intelMac
    case appleSilicon

    nonisolated static var current: HardwareCompatibility {
        var arm64Capability: Int32 = 0
        var capabilitySize = MemoryLayout<Int32>.size

        let result = sysctlbyname(
            "hw.optional.arm64",
            &arm64Capability,
            &capabilitySize,
            nil,
            0
        )

        return result == 0 && arm64Capability == 1 ? .appleSilicon : .intelMac
    }
}

@MainActor
final class TurboKillerModel: ObservableObject {
    let hardware: HardwareCompatibility
    @Published private(set) var turboBoostStatus: TurboBoostStatus = .unavailable
    @Published private(set) var errorMessage: String?

    private let controller: any TurboBoostControlling

    init() {
        hardware = .current
        controller = UnavailableTurboBoostController()
    }

    func refreshStatus() async {
        do {
            turboBoostStatus = try await controller.currentStatus()
            errorMessage = nil
        } catch {
            turboBoostStatus = .unavailable
            errorMessage = error.localizedDescription
        }
    }

    func toggleTurboBoost() async {
        do {
            switch turboBoostStatus {
            case .enabled:
                try await controller.setTurboBoostEnabled(false)
            case .disabled:
                try await controller.setTurboBoostEnabled(true)
            case .unavailable:
                throw TurboBoostControlError.notConnected
            }

            await refreshStatus()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
