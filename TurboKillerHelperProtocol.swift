import Foundation

@objc protocol TurboKillerHelperProtocol {
    func ping(
        withReply reply: @escaping (String, NSNumber) -> Void
    )
}
