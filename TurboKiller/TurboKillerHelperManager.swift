import Foundation
import ServiceManagement

enum TurboKillerHelperState: Equatable {
    case ready
    case requiresApproval
    case unavailable
}

enum TurboKillerHelperManagerError: LocalizedError {
    case helperNotFound
    case registrationFailed(String)

    var errorDescription: String? {
        switch self {
        case .helperNotFound:
            return "The TurboKiller privileged helper could not be found."

        case .registrationFailed(let message):
            return message.isEmpty
                ? "The TurboKiller privileged helper could not be registered."
                : message
        }
    }
}

@MainActor
struct TurboKillerHelperManager {
    private static let plistName =
        "cc.nicotech.TurboKiller.Helper.plist"

    private static var service: SMAppService {
        SMAppService.daemon(plistName: plistName)
    }

    static func prepare() throws -> TurboKillerHelperState {
        let service = service

        switch service.status {
        case .enabled:
            return .ready

        case .requiresApproval:
            return .requiresApproval

        case .notFound:
            throw TurboKillerHelperManagerError.helperNotFound

        case .notRegistered:
            do {
                try service.register()
            } catch {
                // register() may throw while macOS is waiting
                // for the user to approve the LaunchDaemon.
                switch service.status {
                case .enabled:
                    return .ready

                case .requiresApproval:
                    return .requiresApproval

                default:
                    throw TurboKillerHelperManagerError
                        .registrationFailed(
                            error.localizedDescription
                        )
                }
            }

            switch service.status {
            case .enabled:
                return .ready

            case .requiresApproval:
                return .requiresApproval

            default:
                return .unavailable
            }

        @unknown default:
            return .unavailable
        }
    }

    static func repair() async throws -> TurboKillerHelperState {
        let service = service

        if service.status != .notRegistered {
            do {
                try await service.unregister()
            } catch {
                if service.status != .notRegistered {
                    throw TurboKillerHelperManagerError
                        .registrationFailed(
                            "Could not unregister the previous privileged helper: \(error.localizedDescription)"
                        )
                }
            }
        }

        // SMAppService may reject an immediate re-registration
        // even after unregister() has completed.
        //
        // Give Service Management time to finish removing the
        // previous LaunchDaemon before registering the new one.
        await waitForServiceManagement()

        do {
            try service.register()
        } catch {
            switch service.status {
            case .enabled:
                return .ready

            case .requiresApproval:
                return .requiresApproval

            case .notFound:
                throw TurboKillerHelperManagerError.helperNotFound

            case .notRegistered:
                throw TurboKillerHelperManagerError
                    .registrationFailed(
                        error.localizedDescription
                    )

            @unknown default:
                throw TurboKillerHelperManagerError
                    .registrationFailed(
                        error.localizedDescription
                    )
            }
        }

        switch service.status {
        case .enabled:
            return .ready

        case .requiresApproval:
            return .requiresApproval

        case .notFound:
            throw TurboKillerHelperManagerError.helperNotFound

        case .notRegistered:
            return .unavailable

        @unknown default:
            return .unavailable
        }
    }
    
    private static func waitForServiceManagement() async {
        await withCheckedContinuation {
            (continuation: CheckedContinuation<Void, Never>) in

            DispatchQueue.main.asyncAfter(
                deadline: .now() + 2
            ) {
                continuation.resume()
            }
        }
    }

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
