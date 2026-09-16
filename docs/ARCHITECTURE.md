# TurboKiller Architecture

## Product scope

TurboKiller is a free and open-source macOS menu bar utility for compatible
Intel Macs. The initial deployment target is macOS 13.0.

The app may launch on an unsupported Intel CPU, but hardware control must stay
disabled unless the CPU passes explicit compatibility checks. Apple silicon,
Hackintosh, and OpenCore Legacy Patcher environments are outside the supported
scope.

## Components

### Menu bar app

- Swift and SwiftUI.
- Runs as an agent app without a Dock icon or main window.
- Displays hardware compatibility and the verified Turbo Boost state.
- Never reports success based only on local UI state.
- Communicates with the hardware backend through `TurboBoostControlling`.

### Hardware backend

The expected backend is a small, signed Intel kernel extension because public
user-space APIs do not provide arbitrary access to CPU model-specific
registers (MSRs).

The backend must expose only these operations:

1. Read the current Turbo Boost state.
2. Disable Turbo Boost.
3. Restore Turbo Boost.

It must not expose arbitrary MSR addresses or arbitrary write values.

## MSR safety rules

- Confirm that the machine uses a supported Intel CPU.
- Read `IA32_MISC_ENABLE` at `0x1A0` before changing it.
- Change only Turbo Mode Disable bit 38.
- Preserve every other bit in the register.
- Apply the operation to every required logical processor.
- Read the value again after writing and report failure if verification fails.
- Reject unknown CPUs by default.
- Never use a fixed full-register value such as `0x4000850085` or `0x850085`.

## Installation and distribution

Official releases will be distributed from the TurboKiller website and GitHub,
not through the Mac App Store.

The release package must be signed with the appropriate Developer ID
identities and notarized by Apple. The expected first-install flow is:

1. Run the signed installer and authenticate as an administrator.
2. Approve the extension in System Settings > Privacy & Security.
3. Restart the Mac once so macOS can activate the extension.
4. Launch TurboKiller and verify the hardware state.

Normal Turbo Boost toggles must not require a restart. An extension update or
complete uninstall may require another restart.

TurboKiller must work with System Integrity Protection enabled. A release that
requires users to disable SIP, enter a permissive security mode, or run a
quarantine-removal command is not acceptable.

## Development phases

1. **Foundation — complete:** menu bar app, Intel detection, UI state model,
   backend protocol, and local Git repository.
2. **Read-only prototype — build complete, runtime validation pending:** the
   standalone x86_64 Kext compiles against the macOS 26.5 SDK and references
   only `rdmsr_carefully` and logging. It contains no MSR write path. Loading
   and verifying bit 38 is blocked until an appropriate signing identity is
   available; SIP will not be disabled for this test.
3. **Restricted control:** add read-modify-write behavior and post-write
   verification.
4. **Installation:** signed package, approval guidance, activation, update, and
   uninstall flows.
5. **Compatibility:** test supported CPU families and macOS 13 through the
   latest Intel-compatible macOS release.
6. **Release:** security review, documentation, reproducible release process,
   checksums, and public source release.

## Reference implementation findings

Turbo Boost Switcher 2.12.0 uses an older temporary-load approach. Its app
invokes `kextutil` and `kextunload` with administrator authorization, and its
2012-era `DisableTurboBoost` extension declares `OSBundleAllowUserLoad`.
TurboKiller will not depend on this legacy compatibility path because current
macOS releases do not guarantee it for newly developed extensions.
