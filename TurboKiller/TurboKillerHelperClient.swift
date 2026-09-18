import Foundation

struct TurboKillerHelperCommandResult {
    let status: Int32
    let output: String
}

enum TurboKillerHelperClientError: LocalizedError {
    case proxyUnavailable
    case timedOut

    var errorDescription: String? {
        switch self {
        case .proxyUnavailable:
            return String(
                localized:
                    "Could not connect to the TurboKiller privileged helper."
            )

        case .timedOut:
            return String(
                localized:
                    "The TurboKiller privileged helper did not respond."
            )
        }
    }
}

private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var completed = false

    func claim() -> Bool {
        lock.lock()
        defer {
            lock.unlock()
        }

        guard !completed else {
            return false
        }

        completed = true
        return true
    }
}

struct TurboKillerHelperClient {
    private static let machServiceName =
        "cc.nicotech.TurboKiller.Helper"

    private static let helperCodeSigningRequirement =
        #"identifier "TurboKillerHelper" and anchor apple generic and certificate leaf[subject.OU] = "PPXL64QJ2V""#

    static func healthCheck() async throws
        -> TurboKillerHelperCommandResult
    {
        try await perform { proxy, reply in
            proxy.healthCheck(
                withReply: reply
            )
        }
    }

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

            let gate = CompletionGate()

            connection.remoteObjectInterface =
                NSXPCInterface(
                    with: TurboKillerHelperProtocol.self
                )

            connection.setCodeSigningRequirement(
                helperCodeSigningRequirement
            )

            connection.resume()

            Task {
                try? await Task.sleep(
                    nanoseconds: 3_000_000_000
                )

                guard gate.claim() else {
                    return
                }

                connection.invalidate()

                continuation.resume(
                    throwing:
                        TurboKillerHelperClientError
                            .timedOut
                )
            }

            guard let proxy =
                connection.remoteObjectProxyWithErrorHandler({
                    error in

                    guard gate.claim() else {
                        return
                    }

                    connection.invalidate()

                    continuation.resume(
                        throwing: error
                    )
                }) as? TurboKillerHelperProtocol
            else {
                guard gate.claim() else {
                    return
                }

                connection.invalidate()

                continuation.resume(
                    throwing:
                        TurboKillerHelperClientError
                            .proxyUnavailable
                )

                return
            }

            invoke(proxy) { status, output in
                guard gate.claim() else {
                    return
                }

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
