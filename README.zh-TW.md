# TurboKiller

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

TurboKiller 是一款免費、開源的 macOS 選單列工具，用於在相容的 Intel Mac 上控制 Intel Turbo Boost。

> **目前狀態：** 預發佈版本。目前使用的 Legacy Kext 後端已在一台開啟系統完整性保護（SIP）的 Intel Mac 上驗證可用。更多硬體與 macOS 版本相容性測試仍在進行中。
>
> TurboKiller 主程式與特權 Helper 均使用 Developer ID 簽署。但由於目前版本包含一份歷史遺留的未簽署核心延伸模組，Apple 公證服務會拒絕該元件，因此目前版本無法完成 Apple notarization。

## 系統需求

- Intel Mac
- macOS 13 或更新版本
- 無需關閉系統完整性保護（SIP）
- 不支援 Apple 晶片 Mac

## 運作方式

TurboKiller 內建一份固定版本的歷史 `DisableTurboBoost.64bits.kext`。

應用程式透過 `SMAppService` 註冊具有管理員權限的 LaunchDaemon，並透過 XPC 與其通訊。主程式與 Helper 雙方都會驗證對方的程式碼簽署身分。

具有 root 權限的 Helper 會：

- 使用固定的 SHA-256 驗證內建 Kext；
- 將其安裝至 `/Library/Application Support/TurboKiller`；
- 將安裝後的 Kext 擁有者設定為 `root:wheel`；
- 載入 Kext 以停用 Turbo Boost；
- 卸載 Kext 以恢復 Turbo Boost。

TurboKiller 不需要安裝 Turbo Boost Switcher。

Turbo Boost 的目前狀態會透過 `kmutil` 查詢實際載入的 Kext 狀態，而不是只依賴 UI 中的本地狀態。

## 首次執行

由於目前版本未通過 Apple 公證，macOS 第一次開啟 TurboKiller 時可能會阻止執行。

如果發生這種情況：

1. 開啟 **系統設定 → 隱私權與安全性**。
2. 找到關於 TurboKiller 被阻止的提示。
3. 點擊 **仍要開啟** 並確認。

之後 macOS 仍可能分別要求允許：

1. TurboKiller 的背景特權 Helper；
2. Legacy Turbo Boost 核心延伸模組。

允許核心延伸模組後，系統可能要求重新啟動一次。

在全新的系統上，macOS 可能會分別要求允許：

1. TurboKiller 的背景特權 Helper；
2. Legacy Turbo Boost 核心延伸模組。

允許核心延伸模組後，macOS 可能要求重新啟動一次。

完成首次允許後，日常停用或恢復 Turbo Boost 不需要重複輸入管理員密碼，也不需要重新啟動。

## 安全設計

TurboKiller 刻意將特權介面限制在最小範圍。

Helper 不提供任意 Shell 指令執行或任意 MSR 存取能力，只提供準備、載入和卸載固定 Turbo Boost Kext 所需的操作。

主程式與 Helper 會透過程式碼簽署要求互相驗證身分。

執行特權安裝前，內建 Kext 的執行檔也會再次進行 SHA-256 驗證。

## 專案結構

`TurboKiller/`
: 選單列應用程式、UI、狀態管理、Turbo Boost 控制器以及 Helper 用戶端。

`TurboKillerHelper/`
: 以 root 權限執行的 LaunchDaemon，負責 Kext 安裝、載入與卸載。

`TurboKillerHelperProtocol.swift`
: 主程式與 Helper 共用的 XPC 介面。

`TurboKiller/Resources/DisableTurboBoost.64bits.kext`
: 目前後端使用的固定歷史版本 Turbo Boost Kext。

`experiments/TurboKillerKext/`
: 早期唯讀 Kext 可行性實驗，不屬於正式發佈產品。

## 建置

使用 Xcode 開啟 `TurboKiller.xcodeproj`，建置 `TurboKiller` target。

內建的歷史 Kext 必須保持位元組級完全不變。請勿重新編譯、修改或重新簽署。

## 相容性

TurboKiller 使用 Apple 已棄用的 Legacy Kernel Extension 相容機制。

因此無法保證所有 Intel CPU 型號以及未來所有 macOS 版本都能持續相容。

## 授權條款

TurboKiller 依 GNU General Public License version 2 發佈。

專案授權條款請參閱 `LICENSE`，內建第三方元件的來源與授權資訊請參閱 `THIRD_PARTY_NOTICES.md`。