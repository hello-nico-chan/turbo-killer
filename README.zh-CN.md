# TurboKiller

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

TurboKiller 是一款免费、开源的 macOS 菜单栏工具，用于在兼容的 Intel Mac 上控制 Intel Turbo Boost。

> **当前状态：** 预发布版本。当前使用的 Legacy Kext 后端已经在一台开启系统完整性保护（SIP）的 Intel Mac 上验证可用。更多硬件与 macOS 版本兼容性测试仍在进行中。
>
> TurboKiller 主程序和特权 Helper 均使用 Developer ID 签名。但由于当前版本包含一份历史遗留的未签名内核扩展，Apple 公证服务会拒绝该组件，因此当前版本无法完成 Apple notarization。

## 系统要求

- Intel Mac
- macOS 13 或更高版本
- 无需关闭系统完整性保护（SIP）
- 不支持 Apple 芯片 Mac

## 工作原理

TurboKiller 内置了一份固定版本的历史 `DisableTurboBoost.64bits.kext`。

应用通过 `SMAppService` 注册一个具有管理员权限的 LaunchDaemon，并通过 XPC 与它通信。主程序和 Helper 双方都会验证对方的代码签名身份。

具有 root 权限的 Helper 会：

- 使用固定的 SHA-256 校验内置 Kext；
- 将其安装到 `/Library/Application Support/TurboKiller`；
- 将安装后的 Kext 权限设置为 `root:wheel`；
- 加载 Kext 以关闭 Turbo Boost；
- 卸载 Kext 以恢复 Turbo Boost。

TurboKiller 不要求安装 Turbo Boost Switcher。

Turbo Boost 的当前状态通过 `kmutil` 查询实际加载的 Kext 状态确定，而不是仅依赖界面中的本地状态。

## 首次运行

由于当前版本未通过 Apple 公证，macOS 第一次打开 TurboKiller 时可能会阻止运行。

如果发生这种情况：

1. 打开 **系统设置 → 隐私与安全性**。
2. 找到关于 TurboKiller 被阻止的提示。
3. 点击 **仍要打开** 并确认。

之后 macOS 仍可能分别要求批准：

1. TurboKiller 的后台特权 Helper；
2. Legacy Turbo Boost 内核扩展。

批准内核扩展后，系统可能要求重启一次。

完成首次批准后，日常关闭和恢复 Turbo Boost 不需要重复输入管理员密码，也不需要重启。

## 安全设计

TurboKiller 有意将特权接口限制在最小范围。

Helper 不提供执行任意 Shell 命令或访问任意 MSR 的能力，仅提供准备、加载和卸载固定 Turbo Boost Kext 所需的操作。

主程序与 Helper 会通过代码签名要求互相验证身份。

在进行特权安装前，内置 Kext 的可执行文件还会再次进行 SHA-256 校验。

## 项目结构

`TurboKiller/`
: 菜单栏应用、UI、状态管理、Turbo Boost 控制器以及 Helper 客户端。

`TurboKillerHelper/`
: 以 root 权限运行的 LaunchDaemon，负责 Kext 安装、加载和卸载。

`TurboKillerHelperProtocol.swift`
: 主程序和 Helper 共用的 XPC 接口。

`TurboKiller/Resources/DisableTurboBoost.64bits.kext`
: 当前后端使用的固定历史版本 Turbo Boost Kext。

`experiments/TurboKillerKext/`
: 早期只读 Kext 可行性实验，不属于正式发布产品。

## 构建

使用 Xcode 打开 `TurboKiller.xcodeproj`，构建 `TurboKiller` target。

内置的历史 Kext 必须保持字节级完全不变。不要重新编译、修改或重新签名它。

## 兼容性

TurboKiller 使用的是 Apple 已弃用的 Legacy Kernel Extension 兼容机制。

因此无法保证所有 Intel CPU 型号以及未来所有 macOS 版本都能够继续兼容。

## 许可证

TurboKiller 使用 GNU General Public License version 2 发布。

项目许可证请参阅 `LICENSE`，内置第三方组件的来源与许可证信息请参阅 `THIRD_PARTY_NOTICES.md`。