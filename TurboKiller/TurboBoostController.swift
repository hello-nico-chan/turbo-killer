//
//  TurboBoostController.swift
//  TurboKiller
//

import Foundation
import CryptoKit

enum TurboBoostStatus: Equatable {
    case unavailable
    case enabled
    case disabled
}

enum TurboBoostControlError: LocalizedError {
    case notConnected
    case unsupportedMac
    case bundledKextMissing
    case bundledKextModified
    case approvalRequired
    case restartRequired
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Hardware control is not connected."

        case .unsupportedMac:
            return "Turbo Boost control is only available on supported Intel Macs."

        case .bundledKextMissing:
            return "The bundled Turbo Boost kernel extension could not be found."

        case .bundledKextModified:
            return "The bundled Turbo Boost kernel extension does not match the expected version."

        case .approvalRequired:
            return "The kernel extension must be approved in System Settings before it can be used."

        case .restartRequired:
            return "The kernel extension was approved, but macOS requires a restart before it can be used."

        case .commandFailed(let message):
            return message.isEmpty
                ? "Turbo Boost control failed."
                : message
        }
    }
}

protocol TurboBoostControlling {
    func currentStatus() async throws -> TurboBoostStatus
    func setTurboBoostEnabled(_ enabled: Bool) async throws
}

/// Safe placeholder used when hardware control is unavailable.
struct UnavailableTurboBoostController: TurboBoostControlling {
    func currentStatus() async throws -> TurboBoostStatus {
        .unavailable
    }

    func setTurboBoostEnabled(_ enabled: Bool) async throws {
        throw TurboBoostControlError.notConnected
    }
}

/// Controls Turbo Boost by loading/unloading the historical
/// DisableTurboBoost kernel extension.
struct LegacyKextTurboBoostController: TurboBoostControlling {

    private static let bundleIdentifier =
        "com.rugarciap.DisableTurboBoost"

    private static let kextName =
        "DisableTurboBoost.64bits.kext"

    /// Exact SHA-256 of the known working historical binary.
    private static let expectedExecutableSHA256 =
        "f81f003ccd5827122a41c39bddb78e4ffff37d84718a647dbd5fc3c6a92f987c"

    func currentStatus() async throws -> TurboBoostStatus {
#if arch(x86_64)
        return try Self.readCurrentStatus()
#else
        return .unavailable
#endif
    }

    func setTurboBoostEnabled(_ enabled: Bool) async throws {
#if arch(x86_64)
        let current = try Self.readCurrentStatus()

        // Nothing to do.
        if enabled && current == .enabled {
            return
        }

        if !enabled && current == .disabled {
            return
        }

        try await Self.ensureKextInstalled()

        if enabled {
            try await Self.unloadKext()
        } else {
            try await Self.loadKext()
        }

        // Verify the requested state actually took effect.
        let updated = try Self.readCurrentStatus()

        if enabled && updated != .enabled {
            throw TurboBoostControlError.commandFailed(
                "The kernel extension could not be unloaded."
            )
        }

        if !enabled && updated != .disabled {
            throw TurboBoostControlError.commandFailed(
                "The kernel extension could not be loaded."
            )
        }
#else
        throw TurboBoostControlError.unsupportedMac
#endif
    }

    // MARK: - Status

    private static func readCurrentStatus() throws -> TurboBoostStatus {
        let result = try run(
            executable: "/usr/bin/kmutil",
            arguments: ["showloaded"]
        )

        guard result.status == 0 else {
            throw TurboBoostControlError.commandFailed(
                result.output
            )
        }

        return result.output.contains(bundleIdentifier)
            ? .disabled
            : .enabled
    }

    // MARK: - Installation

    private static func ensureKextInstalled() async throws {
        guard
            let resourceURL = Bundle.main.resourceURL?
                .appendingPathComponent(kextName),
            FileManager.default.fileExists(
                atPath: resourceURL.path
            )
        else {
            throw TurboBoostControlError
                .bundledKextMissing
        }

        try verifyExecutableHash(
            kextURL: resourceURL
        )

        let result =
            try await TurboKillerHelperClient
                .prepareTurboBoostKext(
                    sourcePath: resourceURL.path
                )

        guard result.status == 0 else {
            throw TurboBoostControlError
                .commandFailed(result.output)
        }
    }

    // MARK: - Load / Unload

    private static func loadKext() async throws {
        let result =
            try await TurboKillerHelperClient
                .loadTurboBoostKext()

        let output = result.output

        if output.localizedCaseInsensitiveContains(
            "not approved to load"
        ) {
            throw TurboBoostControlError
                .approvalRequired
        }

        if output.localizedCaseInsensitiveContains(
            "requires a reboot"
        ) {
            throw TurboBoostControlError
                .restartRequired
        }

        guard result.status == 0 else {
            throw TurboBoostControlError
                .commandFailed(output)
        }
    }

    private static func unloadKext() async throws {
        let result =
            try await TurboKillerHelperClient
                .unloadTurboBoostKext()

        guard result.status == 0 else {
            throw TurboBoostControlError
                .commandFailed(result.output)
        }
    }
    
    // MARK: - Hash verification

    private static func verifyExecutableHash(
        kextURL: URL
    ) throws {
        let hash = try executableHash(kextURL: kextURL)

        guard hash == expectedExecutableSHA256 else {
            throw TurboBoostControlError.bundledKextModified
        }
    }

    private static func executableHash(
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

    // MARK: - Process execution

    private struct CommandResult {
        let status: Int32
        let output: String
    }

    private static func run(
        executable: String,
        arguments: [String]
    ) throws -> CommandResult {
        let process = Process()

        let stdout = Pipe()
        let stderr = Pipe()

        process.executableURL =
            URL(fileURLWithPath: executable)

        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw TurboBoostControlError.commandFailed(
                error.localizedDescription
            )
        }

        process.waitUntilExit()

        let stdoutData =
            stdout.fileHandleForReading.readDataToEndOfFile()

        let stderrData =
            stderr.fileHandleForReading.readDataToEndOfFile()

        let stdoutString =
            String(data: stdoutData, encoding: .utf8) ?? ""

        let stderrString =
            String(data: stderrData, encoding: .utf8) ?? ""

        let output = [
            stdoutString,
            stderrString
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return CommandResult(
            status: process.terminationStatus,
            output: output
        )
    }
}
