# TurboKiller

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

TurboKiller is a free and open-source macOS menu bar utility for controlling Intel Turbo Boost on compatible Intel Macs.

> **Status:** Pre-release. The current legacy Kext backend has been validated on an Intel Mac with System Integrity Protection enabled. Broader hardware and macOS compatibility testing are still in progress.
>
> TurboKiller and its privileged helper are Developer ID signed. However, the current release is not Apple-notarized because it includes a historical unsigned kernel extension that Apple's notary service rejects.

## Requirements

- Intel Mac
- macOS 13 or later
- System Integrity Protection may remain enabled
- Apple silicon is not supported

## How it works

TurboKiller bundles a pinned historical `DisableTurboBoost.64bits.kext`.

The app registers a privileged LaunchDaemon using `SMAppService`. The menu bar app communicates with this helper over XPC, with code-signing requirements enforced on both sides.

The privileged helper:

- verifies the bundled Kext executable against a pinned SHA-256 hash;
- installs it under `/Library/Application Support/TurboKiller`;
- sets the installed bundle ownership to `root:wheel`;
- loads the Kext to disable Turbo Boost;
- unloads the Kext to restore Turbo Boost.

TurboKiller does not require Turbo Boost Switcher to be installed.

The current Turbo Boost state is determined from the actual loaded Kext state using `kmutil`, rather than from UI state alone.

## First run

Because the current release is not notarized, macOS may block TurboKiller the first time you open it.

If this happens:

1. Open **System Settings → Privacy & Security**.
2. Find the message about TurboKiller being blocked.
3. Click **Open Anyway** and confirm.

After that, macOS may still separately ask you to approve:

1. TurboKiller's privileged background helper.
2. The legacy Turbo Boost kernel extension.

A restart may be required after approving the kernel extension.

On a clean system, macOS may require approval for two separate components:

1. TurboKiller's privileged background helper.
2. The legacy Turbo Boost kernel extension.

macOS may require one restart after the kernel extension is approved.

After the helper and Kext have been approved, normal Turbo Boost switching does not require an administrator password or a restart.

## Security

TurboKiller intentionally keeps its privileged interface small.

The helper does not expose arbitrary shell execution or arbitrary MSR access. It exposes only the operations required to prepare, load, and unload the pinned Turbo Boost Kext.

The app and helper authenticate each other using code-signing requirements tied to the TurboKiller identifiers and developer team.

The bundled Kext executable is verified using SHA-256 before privileged installation.

## Project layout

`TurboKiller/`
: Menu bar app, UI, state model, Turbo Boost controller, and privileged-helper client.

`TurboKillerHelper/`
: Root LaunchDaemon used for privileged Kext installation and load/unload operations.

`TurboKillerHelperProtocol.swift`
: Shared XPC interface.

`TurboKiller/Resources/DisableTurboBoost.64bits.kext`
: Pinned historical Turbo Boost Kext used by the current backend.

`experiments/TurboKillerKext/`
: Earlier read-only Kext feasibility experiment. It is not part of the shipping product.

## Building

Open `TurboKiller.xcodeproj` in Xcode and build the `TurboKiller` target.

The historical bundled Kext must remain byte-for-byte unchanged. Do not rebuild, modify, or re-sign it.

## Compatibility

TurboKiller relies on a legacy kernel-extension compatibility path that Apple has deprecated.

Compatibility is therefore not guaranteed across every Intel CPU family or every future macOS release.

## License

TurboKiller is distributed under the GNU General Public License version 2.

See `LICENSE` for the project license and `THIRD_PARTY_NOTICES.md` for attribution and licensing information about bundled third-party components.