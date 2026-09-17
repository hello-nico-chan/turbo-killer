import Darwin
import Foundation
import os

private let machServiceName =
    "cc.nicotech.TurboKiller.Helper"

private let logger = Logger(
    subsystem: "cc.nicotech.TurboKiller",
    category: "helper"
)

private let appCodeSigningRequirement =
    #"identifier "cc.nicotech.TurboKiller" and anchor apple generic and certificate leaf[subject.OU] = "PPXL64QJ2V""#

final class TurboKillerHelperService:
    NSObject,
    TurboKillerHelperProtocol
{
    func ping(
        withReply reply: @escaping (String, NSNumber) -> Void
    ) {
        let uid = getuid()

        logger.log(
            "Ping received. uid=\(uid, privacy: .public)"
        )

        reply(
            "TurboKillerHelper is alive",
            NSNumber(value: uid)
        )
    }
}

final class TurboKillerHelperListener:
    NSObject,
    NSXPCListenerDelegate
{
    private let service =
        TurboKillerHelperService()

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection newConnection: NSXPCConnection
    ) -> Bool {
        newConnection.setCodeSigningRequirement(
            appCodeSigningRequirement
        )

        newConnection.exportedInterface =
            NSXPCInterface(
                with: TurboKillerHelperProtocol.self
            )

        newConnection.exportedObject = service

        newConnection.resume()

        logger.log("Accepted signed XPC connection")

        return true
    }
}

let delegate = TurboKillerHelperListener()

let listener = NSXPCListener(
    machServiceName: machServiceName
)

listener.delegate = delegate

logger.log("TurboKillerHelper XPC listener started")

listener.resume()

dispatchMain()
