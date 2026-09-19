# TurboKiller

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

[![Latest release](https://img.shields.io/github/v/release/hello-nico-chan/turbo-killer?display_name=tag&sort=semver&style=flat-square)](https://github.com/hello-nico-chan/turbo-killer/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/hello-nico-chan/turbo-killer/total?style=flat-square)](https://github.com/hello-nico-chan/turbo-killer/releases)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Intel Mac](https://img.shields.io/badge/Mac-Intel-0071C5?style=flat-square&logo=intel&logoColor=white)
[![GPL-2.0](https://img.shields.io/github/license/hello-nico-chan/turbo-killer?style=flat-square)](LICENSE)

TurboKiller is a free and open-source macOS menu bar utility for controlling Intel Turbo Boost on compatible Intel Macs.

> **Status:** The current legacy Kext backend has been validated on an Intel Mac with System Integrity Protection enabled. Broader hardware and macOS compatibility cannot be guaranteed.
>
> TurboKiller and its privileged helper are Developer ID signed. However, the current release is not Apple-notarized because it includes a historical unsigned kernel extension that Apple's notary service rejects.

## Requirements

- Intel Mac
- macOS 13 or later
- System Integrity Protection may remain enabled

## How it works

TurboKiller bundles a pinned historical `DisableTurboBoost.64bits.kext`.

The app registers a privileged LaunchDaemon using `SMAppService`. The menu bar app communicates with this helper over XPC, with code-signing requirements enforced on both sides.

The privileged helper:

- verifies the bundled Kext executable against a pinned SHA-256 hash;
- installs it under `/Library/Application Support/TurboKiller`;
- sets the installed bundle ownership to `root:wheel`;
- loads the Kext to disable Turbo Boost;
- unloads the Kext to restore Turbo Boost.

The current Turbo Boost state is determined from the actual loaded Kext state using `kmutil`, rather than from UI state alone.

## First run

Because the current release is not notarized, macOS may block TurboKiller the first time you open it.

If this happens:

1. Open **System Settings → Privacy & Security**.
2. Find the message about TurboKiller being blocked.
3. Click **Open Anyway** and confirm.

After that, macOS may still separately ask you to approve:

1. TurboKiller's privileged background helper. Open **System Settings → General → Login Items & Extensions → allow TurboKiller to run in the background**.
2. The legacy Turbo Boost kernel extension.

A restart may be required after approving the kernel extension.

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

## Building

Open `TurboKiller.xcodeproj` in Xcode and build the `TurboKiller` target.

The historical bundled Kext must remain byte-for-byte unchanged. Do not rebuild, modify, or re-sign it.

## Compatibility

TurboKiller relies on a legacy kernel-extension compatibility path that Apple has deprecated.

Compatibility is therefore not guaranteed across every Intel CPU family or every future macOS release.

If you try TurboKiller on another Intel Mac, a compatibility report is welcome — successful reports are useful too.

## Official releases

The canonical source for official TurboKiller releases is this repository:

`https://github.com/hello-nico-chan/turbo-killer`

Official release builds are signed with the NicoTech Studio Developer ID.

Forks and modified builds are welcome under the GPLv2 license, but they should clearly identify themselves as modified builds and should not imply that they are official TurboKiller releases.

## Support

If TurboKiller is useful to you and you would like to support its development:

<a href="https://ko-fi.com/hello_nico_chan"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=3" height="36" alt="Support me on Ko-fi"></a>

## License

TurboKiller is distributed under the GNU General Public License version 2.

See `LICENSE` for the project license and `THIRD_PARTY_NOTICES.md` for attribution and licensing information about bundled third-party components.