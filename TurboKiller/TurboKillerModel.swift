//
//  TurboKillerModel.swift
//  TurboKiller
//

import Darwin
import Combine
import Foundation

enum HardwareCompatibility: Equatable {
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

        return result == 0 && arm64Capability == 1
            ? .appleSilicon
            : .intelMac
    }
}

enum TurboKillerRequiredAction: Equatable {
    case approvePrivilegedHelper
    case approveKernelExtension
    case restartRequired
}

@MainActor
final class TurboKillerModel: ObservableObject {
    let hardware: HardwareCompatibility

    @Published private(set) var turboBoostStatus: TurboBoostStatus = .unavailable
    @Published private(set) var errorMessage: String?
    @Published private(set) var requiredAction: TurboKillerRequiredAction?
    @Published private(set) var isBusy = false
    @Published private(set) var helperReady = false

    private let controller: any TurboBoostControlling

    init() {
        hardware = .current
        controller = LegacyKextTurboBoostController()
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
        guard !isBusy else {
            return
        }
        
        if !helperReady {
            prepareHelper()

            guard helperReady else {
                return
            }
        }

        isBusy = true
        errorMessage = nil
        requiredAction = nil

        defer {
            isBusy = false
        }

        do {
            switch turboBoostStatus {
            case .enabled:
                try await controller.setTurboBoostEnabled(false)

            case .disabled:
                try await controller.setTurboBoostEnabled(true)

            case .unavailable:
                throw TurboBoostControlError.notConnected
            }

            turboBoostStatus = try await controller.currentStatus()

        } catch let error as TurboBoostControlError {
            handleControlError(error)

        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func handleControlError(_ error: TurboBoostControlError) {
        switch error {
        case .approvalRequired:
            requiredAction = .approveKernelExtension

        case .restartRequired:
            requiredAction = .restartRequired

        default:
            errorMessage = error.localizedDescription
        }
    }
    
    func prepareHelper() {
        guard hardware == .intelMac else {
            helperReady = false
            requiredAction = nil
            errorMessage = nil
            return
        }
        
        do {
            let state = try TurboKillerHelperManager.prepare()

            switch state {
            case .ready:
                helperReady = true

                if requiredAction == .approvePrivilegedHelper {
                    requiredAction = nil
                }

            case .requiresApproval:
                helperReady = false
                requiredAction = .approvePrivilegedHelper

            case .unavailable:
                helperReady = false
                errorMessage =
                    "The TurboKiller privileged helper is unavailable."
            }
        } catch {
            helperReady = false
            errorMessage = error.localizedDescription
        }
    }
}
