import Foundation

struct TurboKillerHelperCommandResult {
    let status: Int32
    let output: String
}

enum TurboKillerHelperClientError: LocalizedError {
    case proxyUnavailable

    var errorDescription: String? {
        switch self {
        case .proxyUnavailable:
            return "Could not connect to the TurboKiller privileged helper."
        }
    }
}

struct TurboKillerHelperClient {
    private static let machServiceName =
        "cc.nicotech.TurboKiller.Helper"

    private static let helperCodeSigningRequirement =
        #"identifier "TurboKillerHelper" and anchor apple generic and certificate leaf[subject.OU] = "PPXL64QJ2V""#
    
    static func prepareTurboBoostKext() async throws
    -> TurboKillerHelperCommandResult
    {
        try await perform { proxy, reply in
            proxy.prepareTurboBoostKext(
                withReply: reply
            )
        }
    }

    static func loadTurboBoostKext() async throws
        -> TurboKillerHelperCommandResult
    {
        try await perform { proxy, reply in
            proxy.loadTurboBoostKext(
                withReply: reply
            )
        }
    }

    static func unloadTurboBoostKext() async throws
        -> TurboKillerHelperCommandResult
    {
        try await perform { proxy, reply in
            proxy.unloadTurboBoostKext(
                withReply: reply
            )
        }
    }

    private static func perform(
        _ invoke: @escaping (
            TurboKillerHelperProtocol,
            @escaping (NSNumber, String) -> Void
        ) -> Void
    ) async throws -> TurboKillerHelperCommandResult {
        try await withCheckedThrowingContinuation {
            continuation in

            let connection = NSXPCConnection(
                machServiceName: machServiceName,
                options: .privileged
            )

            connection.remoteObjectInterface =
                NSXPCInterface(
                    with: TurboKillerHelperProtocol.self
                )

            connection.setCodeSigningRequirement(
                helperCodeSigningRequirement
            )

            connection.resume()

            guard let proxy =
                connection.remoteObjectProxyWithErrorHandler({
                    error in

                    connection.invalidate()

                    continuation.resume(
                        throwing: error
                    )
                }) as? TurboKillerHelperProtocol
            else {
                connection.invalidate()

                continuation.resume(
                    throwing:
                        TurboKillerHelperClientError
                            .proxyUnavailable
                )

                return
            }

            invoke(proxy) { status, output in
                let result =
                    TurboKillerHelperCommandResult(
                        status: status.int32Value,
                        output: output
                    )

                connection.invalidate()

                continuation.resume(
                    returning: result
                )
            }
        }
    }
}
