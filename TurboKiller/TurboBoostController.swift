//
//  TurboBoostController.swift
//  TurboKiller
//

import Foundation

enum TurboBoostStatus: Equatable {
    case unavailable
    case enabled
    case disabled
}

enum TurboBoostControlError: LocalizedError {
    case notConnected

    var errorDescription: String? {
        switch self {
        case .notConnected:
            "Hardware control is not connected."
        }
    }
}

protocol TurboBoostControlling {
    func currentStatus() async throws -> TurboBoostStatus
    func setTurboBoostEnabled(_ enabled: Bool) async throws
}

/// Safe placeholder used until the privileged hardware backend is available.
struct UnavailableTurboBoostController: TurboBoostControlling {
    func currentStatus() async throws -> TurboBoostStatus {
        .unavailable
    }

    func setTurboBoostEnabled(_ enabled: Bool) async throws {
        throw TurboBoostControlError.notConnected
    }
}
