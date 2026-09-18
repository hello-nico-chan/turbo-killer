import Foundation

@objc protocol TurboKillerHelperProtocol {
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