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

    static func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
