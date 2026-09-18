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
            await prepareHelper()

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
            try await performToggle()

        } catch let error as TurboBoostControlError {
            handleControlError(error)

        } catch {
            // The registered helper may belong to an older copy of
            // TurboKiller. Re-register the helper from the current app
            // bundle and retry once.
            do {
                let state =
                    try await TurboKillerHelperManager.repair()

                switch state {
                case .ready:
                    helperReady = true
                    try await performToggle()

                case .requiresApproval:
                    helperReady = false
                    requiredAction = .approvePrivilegedHelper

                case .unavailable:
                    helperReady = false
                    errorMessage =
                        "The TurboKiller privileged helper is unavailable."
                }

            } catch let controlError as TurboBoostControlError {
                handleControlError(controlError)

            } catch {
                helperReady = false
                errorMessage = error.localizedDescription
            }
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
    
    private func performToggle() async throws {
        switch turboBoostStatus {
        case .enabled:
            try await controller.setTurboBoostEnabled(false)

        case .disabled:
            try await controller.setTurboBoostEnabled(true)

        case .unavailable:
            throw TurboBoostControlError.notConnected
        }

        turboBoostStatus = try await controller.currentStatus()
    }
    
    func prepareHelper() async {
        guard hardware == .intelMac else {
            helperReady = false
            requiredAction = nil
            errorMessage = nil
            return
        }

        helperReady = false

        do {
            var state =
                try TurboKillerHelperManager.prepare()

            // "enabled" only means Service Management has a registration.
            // Verify that the helper can actually respond over XPC.
            if state == .ready {
                do {
                    let result =
                        try await TurboKillerHelperClient
                            .healthCheck()

                    guard result.status == 0 else {
                        throw TurboKillerHelperClientError
                            .proxyUnavailable
                    }

                } catch {
                    // The registered helper may belong to an old or
                    // no-longer-existing copy of TurboKiller.
                    state =
                        try await TurboKillerHelperManager
                            .repair()

                    if state == .ready {
                        let result =
                            try await TurboKillerHelperClient
                                .healthCheck()

                        guard result.status == 0 else {
                            throw TurboKillerHelperClientError
                                .proxyUnavailable
                        }
                    }
                }
            }

            switch state {
            case .ready:
                helperReady = true
                errorMessage = nil

                if requiredAction ==
                    .approvePrivilegedHelper
                {
                    requiredAction = nil
                }

            case .requiresApproval:
                helperReady = false
                requiredAction =
                    .approvePrivilegedHelper

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
