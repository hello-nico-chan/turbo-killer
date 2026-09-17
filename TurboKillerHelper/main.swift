import CryptoKit
import Darwin
import Foundation
import os

private let machServiceName =
    "cc.nicotech.TurboKiller.Helper"

private let installedKextPath =
    "/Library/Application Support/TurboKiller/DisableTurboBoost.64bits.kext"

private let expectedExecutableSHA256 =
    "f81f003ccd5827122a41c39bddb78e4ffff37d84718a647dbd5fc3c6a92f987c"

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
    func prepareTurboBoostKext(
        sourcePath: String,
        withReply reply: @escaping (NSNumber, String) -> Void
    ) {
        logger.log("Preparing Turbo Boost kext")

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let destinationURL = URL(fileURLWithPath: installedKextPath)

        do {
            guard
                FileManager.default.fileExists(
                    atPath: sourceURL.path
                )
            else {
                reply(
                    NSNumber(value: -1),
                    "The bundled Turbo Boost kernel extension could not be found."
                )
                return
            }

            guard
                try executableHash(kextURL: sourceURL)
                    == expectedExecutableSHA256
            else {
                reply(
                    NSNumber(value: -1),
                    "The bundled Turbo Boost kernel extension failed integrity verification."
                )
                return
            }

            if
                FileManager.default.fileExists(
                    atPath: destinationURL.path
                ),
                try executableHash(kextURL: destinationURL)
                    == expectedExecutableSHA256,
                hasRootOwnership(destinationURL)
            {
                reply(NSNumber(value: 0), "")
                return
            }

            let installDirectory =
                destinationURL.deletingLastPathComponent()

            try FileManager.default.createDirectory(
                at: installDirectory,
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(
                atPath: destinationURL.path
            ) {
                try FileManager.default.removeItem(
                    at: destinationURL
                )
            }

            let copyResult = run(
                executable: "/usr/bin/ditto",
                arguments: [
                    sourceURL.path,
                    destinationURL.path
                ]
            )

            guard copyResult.status == 0 else {
                reply(
                    NSNumber(value: copyResult.status),
                    copyResult.output
                )
                return
            }

            let ownershipResult = run(
                executable: "/usr/sbin/chown",
                arguments: [
                    "-R",
                    "root:wheel",
                    destinationURL.path
                ]
            )

            guard ownershipResult.status == 0 else {
                reply(
                    NSNumber(value: ownershipResult.status),
                    ownershipResult.output
                )
                return
            }

            guard
                try executableHash(kextURL: destinationURL)
                    == expectedExecutableSHA256
            else {
                reply(
                    NSNumber(value: -1),
                    "The installed Turbo Boost kernel extension failed integrity verification."
                )
                return
            }

            logger.log("Turbo Boost kext prepared")

            reply(NSNumber(value: 0), "")

        } catch {
            reply(
                NSNumber(value: -1),
                error.localizedDescription
            )
        }
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
    
    private func executableHash(
        kextURL: URL
    ) throws -> String {
        let executableURL = kextURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("MacOS")
            .appendingPathComponent("DisableTurboBoost")

        let data = try Data(contentsOf: executableURL)

        return SHA256
            .hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func hasRootOwnership(
        _ url: URL
    ) -> Bool {
        guard
            let attributes = try? FileManager.default
                .attributesOfItem(atPath: url.path),
            let owner =
                attributes[.ownerAccountID] as? NSNumber,
            let group =
                attributes[.groupOwnerAccountID] as? NSNumber
        else {
            return false
        }

        return owner.intValue == 0 &&
               group.intValue == 0
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
