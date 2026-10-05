# Project Brain: Sonotype

> **Single Source of Local Truth**: Maintained across all agent sessions. Append or update when architectural decisions are ratified, shortcuts are logged, or operational quirks are discovered.

---

## 1. Architectural Map & Active Invariants
- **Product Name**: Sonotype (derived from VoiceInk)
- **Target OS**: macOS 15.0+ (Sequoia)
- **Core Runtime & Language**: Swift 6, SwiftUI, SwiftData
- **Audio & Speech Pipeline**:
  - Audio capture via `CoreAudioRecorder` (PCM 16kHz mono)
  - Transcription via local `whisper.xcframework` (`ggml-*.bin` + CoreML encoders) and native `AppleSpeech` framework
  - Delivery via macOS Accessibility API / CGEvent (`CursorPaster`, `KeySender`)
- **Strict Invariant: Dual-Language Scope (EN + PT)**:
  - The application is exclusively bilingual: English (`en`, `en-US`, `en-GB`) and Portuguese (`pt`, `pt-PT`, `pt-BR`), plus intelligent `auto` detection between the two.
  - All third-party languages (French, German, Chinese, and the 90+ non-EN/PT Whisper matrix entries) are pruned to maximize code economy and reduce cognitive and binary bloat.
- **Build Mode**: Local development uses `make local` with the `LOCAL_BUILD` Swift flag, which enables `.licensed` mode out-of-the-box and uses ad-hoc / Apple Development code signing.

---

## 2. Decision Log (MADR Index)
| Date | MADR ID | Title | Status | Decided By |
| :--- | :--- | :--- | :--- | :--- |
| 2026-10-05 | [ADR-001](adr/2026-10-05-sonotype-architecture-and-bilingual-scope.md) | Sonotype Architecture and Dual-Language (EN/PT) Scope | Accepted | orchestrator |

---

## 3. Ponytail Debt Ledger
Tracks deliberate simplifications marked with `# ponytail: <ceiling>, <upgrade path>`:
| File:Line | Ceiling (When to refactor) | Upgrade Path | Date Logged |
| :--- | :--- | :--- | :--- |
| `None` | - | - | 2026-10-05 |

---

## 4. Operational Quirks & Local Gotchas
- **Whisper Framework**: Requires building `whisper.xcframework` via `make whisper` before `xcodebuild` succeeds. Dependencies are stored in `~/VoiceInk-Dependencies` (or `~/Sonotype-Dependencies`).
- **Signing & Entitlements**: Local builds use `VoiceInk.local.entitlements` and `LocalBuild.xcconfig`. When signing without paid Apple Developer certificates, ad-hoc signing (`LOCAL_CODESIGN_IDENTITY=-`) is used.
- **Secret Scanning**: Historical upstream commits with leaked demo tokens were purged via orphan branch initialization. Never check in hardcoded API tokens.
