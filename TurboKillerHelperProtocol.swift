import Foundation

@objc protocol TurboKillerHelperProtocol {
    func ping(
        withReply reply: @escaping (String, NSNumber) -> Void
    )

    func loadTurboBoostKext(
        withReply reply: @escaping (NSNumber, String) -> Void
    )

    func unloadTurboBoostKext(
        withReply reply: @escaping (NSNumber, String) -> Void
    )
}
