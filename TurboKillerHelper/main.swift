import Darwin
import Foundation
import os

private let machServiceName =
    "cc.nicotech.TurboKiller.Helper"

private let installedKextPath =
    "/Library/Application Support/TurboKiller/DisableTurboBoost.64bits.kext"

private let appCodeSigningRequirement =
    #"identifier "cc.nicotech.TurboKiller" and anchor apple generic and certificate leaf[subject.OU] = "PPXL64QJ2V""#

private let logger = Logger(
    subsystem: "cc.nicotech.TurboKiller",
    category: "helper"
)

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

    func loadTurboBoostKext(
        withReply reply: @escaping (NSNumber, String) -> Void
    ) {
        logger.log("Loading Turbo Boost kext")

        let result = run(
            executable: "/usr/bin/kextutil",
            arguments: [
                "-v",
                installedKextPath
            ]
        )

        logger.log(
            "kextutil finished with status \(result.status, privacy: .public)"
        )

        reply(
            NSNumber(value: result.status),
            result.output
        )
    }

    func unloadTurboBoostKext(
        withReply reply: @escaping (NSNumber, String) -> Void
    ) {
        logger.log("Unloading Turbo Boost kext")

        let result = run(
            executable: "/sbin/kextunload",
            arguments: [
                "-v",
                installedKextPath
            ]
        )

        logger.log(
            "kextunload finished with status \(result.status, privacy: .public)"
        )

        reply(
            NSNumber(value: result.status),
            result.output
        )
    }

    private func run(
        executable: String,
        arguments: [String]
    ) -> (status: Int32, output: String) {
        let process = Process()
        let pipe = Pipe()

        process.executableURL =
            URL(fileURLWithPath: executable)

        process.arguments = arguments

        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
        } catch {
            return (
                -1,
                error.localizedDescription
            )
        }

        process.waitUntilExit()

        let data =
            pipe.fileHandleForReading.readDataToEndOfFile()

        let output =
            String(data: data, encoding: .utf8)?
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                ) ?? ""

        return (
            process.terminationStatus,
            output
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
