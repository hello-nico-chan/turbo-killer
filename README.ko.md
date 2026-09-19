# TurboKiller

[English](README.md) | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

[![Latest release](https://img.shields.io/github/v/release/hello-nico-chan/turbo-killer?display_name=tag&sort=semver&style=flat-square)](https://github.com/hello-nico-chan/turbo-killer/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/hello-nico-chan/turbo-killer/total?style=flat-square)](https://github.com/hello-nico-chan/turbo-killer/releases)
![macOS 13+](https://img.shields.io/badge/macOS-13%2B-000000?style=flat-square&logo=apple&logoColor=white)
![Intel Mac](https://img.shields.io/badge/Mac-Intel-0071C5?style=flat-square&logo=intel&logoColor=white)
[![GPL-2.0](https://img.shields.io/github/license/hello-nico-chan/turbo-killer?style=flat-square)](LICENSE)

TurboKiller는 호환되는 Intel Mac에서 Intel Turbo Boost를 제어하기 위한 무료 오픈 소스 macOS 메뉴 막대 유틸리티입니다.

> **현재 상태:** 현재 Legacy Kext 백엔드는 System Integrity Protection(SIP)이 활성화된 Intel Mac에서 동작이 확인되었습니다. 더 넓은 하드웨어 및 macOS 버전과의 호환성은 보장되지 않습니다.
>
> TurboKiller 본체와 권한이 있는 Helper는 Developer ID로 서명되어 있습니다. 다만 현재 릴리스에는 과거의 서명되지 않은 커널 확장이 포함되어 있으며, Apple 공증 서비스가 이 구성 요소를 거부하기 때문에 현재 릴리스는 Apple notarization을 완료할 수 없습니다.

## 요구 사항

- Intel Mac
- macOS 13 이상
- System Integrity Protection(SIP)을 비활성화할 필요 없음

## 작동 방식

TurboKiller에는 고정된 과거 버전의 `DisableTurboBoost.64bits.kext`가 포함되어 있습니다.

앱은 `SMAppService`를 사용해 권한이 있는 LaunchDaemon을 등록하고 XPC를 통해 통신합니다. 앱과 Helper 양쪽 모두 코드 서명 요구 사항을 사용하여 상대방의 신원을 검증합니다.

root 권한으로 실행되는 Helper는 다음 작업을 수행합니다.

- 포함된 Kext 실행 파일을 고정된 SHA-256 해시와 비교
- `/Library/Application Support/TurboKiller`에 설치
- 설치된 Kext의 소유권을 `root:wheel`로 설정
- Kext를 로드하여 Turbo Boost 비활성화
- Kext를 언로드하여 Turbo Boost 복원

현재 Turbo Boost 상태는 UI 내부 상태가 아니라 `kmutil`을 이용해 실제로 로드된 Kext 상태를 확인하여 판단합니다.

## 최초 실행

현재 릴리스는 Apple 공증을 받지 않았기 때문에 처음 실행할 때 macOS가 TurboKiller를 차단할 수 있습니다.

이 경우:

1. **시스템 설정 → 개인정보 보호 및 보안**을 엽니다.
2. TurboKiller가 차단되었다는 메시지를 찾습니다.
3. **그래도 열기**를 클릭하고 확인합니다.

그 후 macOS가 다음 구성 요소에 대해 별도로 승인을 요구할 수 있습니다.

1. TurboKiller의 권한 있는 백그라운드 Helper. **시스템 설정 → 일반 → 로그인 항목 및 확장 프로그램 → TurboKiller 백그라운드 실행 허용**에서 승인합니다
2. Legacy Turbo Boost 커널 확장

커널 확장을 승인한 뒤 한 번 재시작해야 할 수 있습니다.

최초 승인이 완료된 뒤에는 일반적인 Turbo Boost 전환 시 관리자 암호 입력이나 재시작이 필요하지 않습니다.

## 보안

TurboKiller는 권한 인터페이스를 의도적으로 최소화했습니다.

Helper는 임의의 Shell 명령 실행이나 임의의 MSR 접근 기능을 제공하지 않으며, 고정된 Turbo Boost Kext를 준비하고 로드하거나 언로드하는 데 필요한 작업만 제공합니다.

앱과 Helper는 코드 서명 요구 사항을 이용해 서로를 인증합니다.

권한이 필요한 설치를 수행하기 전에 포함된 Kext 실행 파일을 SHA-256으로 다시 검증합니다.

## 프로젝트 구조

`TurboKiller/`
: 메뉴 막대 앱, UI, 상태 모델, Turbo Boost 컨트롤러 및 Helper 클라이언트.

`TurboKillerHelper/`
: root 권한으로 실행되며 Kext 설치, 로드 및 언로드를 담당하는 LaunchDaemon.

`TurboKillerHelperProtocol.swift`
: 앱과 Helper가 공유하는 XPC 인터페이스.

`TurboKiller/Resources/DisableTurboBoost.64bits.kext`
: 현재 백엔드가 사용하는 고정된 과거 Turbo Boost Kext.

## 빌드

Xcode에서 `TurboKiller.xcodeproj`를 열고 `TurboKiller` target을 빌드합니다.

포함된 과거 Kext는 바이트 단위로 그대로 유지되어야 합니다. 다시 빌드하거나 수정하거나 재서명하지 마십시오.

## 호환성

TurboKiller는 Apple이 더 이상 권장하지 않는 Legacy Kernel Extension 호환 경로에 의존합니다.

따라서 모든 Intel CPU 계열이나 향후 모든 macOS 버전에서의 동작을 보장할 수 없습니다.

다른 Intel Mac에서 TurboKiller를 사용해 보았다면 호환성 보고를 환영합니다. 정상적으로 작동한 보고도 똑같이 유용합니다.

## 공식 릴리스

TurboKiller 공식 릴리스의 정식 배포처는 이 저장소입니다.

`https://github.com/hello-nico-chan/turbo-killer`

공식 릴리스는 NicoTech Studio의 Developer ID로 서명됩니다.

GPLv2에 따라 Fork, 수정 및 재배포할 수 있지만, 수정된 빌드는 수정 버전임을 명확히 표시하고 TurboKiller의 공식 릴리스인 것처럼 오해하게 해서는 안 됩니다.

## 후원

TurboKiller가 도움이 되었고 향후 개발을 지원하고 싶다면:

<a href="https://ko-fi.com/hello_nico_chan"><img src="https://storage.ko-fi.com/cdn/kofi3.png?v=3" height="36" alt="Ko-fi에서 후원하기"></a>

## 라이선스

TurboKiller는 GNU General Public License version 2로 배포됩니다.

프로젝트 라이선스는 `LICENSE`, 포함된 제3자 구성 요소의 출처 및 라이선스 정보는 `THIRD_PARTY_NOTICES.md`를 참고하십시오.