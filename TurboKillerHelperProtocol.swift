import Foundation

@objc protocol TurboKillerHelperProtocol {
    func healthCheck(
        withReply reply: @escaping (NSNumber, String) -> Void
    )

    func prepareTurboBoostKext(
        withReply reply: @escaping (NSNumber, String) -> Void
    )

    func loadTurboBoostKext(
        withReply reply: @escaping (NSNumber, String) -> Void
    )

    func unloadTurboBoostKext(
        withReply reply: @escaping (NSNumber, String) -> Void
    )
}
