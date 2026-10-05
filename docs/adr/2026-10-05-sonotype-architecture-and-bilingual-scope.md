# ADR-001: Sonotype Architecture and Dual-Language (EN/PT) Scope

* Status: accepted
* Deciders: Human Developer, Orchestrator
* Date: 2026-10-05

## Context and Problem Statement
The VoiceInk upstream codebase was built as a multi-language voice-to-text dictation application for macOS supporting 100+ transcription languages, alongside partial UI translations (en, de, fr, zh-Hans).
The user wants to specialize and develop **Sonotype** exclusively for **English and Portuguese** (Portugal and Brazil), eliminating extraneous language overhead, dead UI strings, and non-target language models, while ensuring complete Portuguese localization and optimized dual-language prompts.

## Decision Drivers
* **Code Economy (Ponytail Principles)**: Eliminate unused localization catalogs (German, French, Simplified Chinese) and 90+ non-target languages in speech selection dictionaries.
* **Specialized User Experience**: First-class support for English (`en`, `en-US`, `en-GB`) and Portuguese (`pt`, `pt-PT`, `pt-BR`) with automatic bilingual switching.
* **Apple HIG & macOS Native Feel**: Retain native SwiftUI components, semantic materials (`.regularMaterial`), SF Pro Text/Display optical sizing, and 44x44pt touch targets.
* **Zero Downtime / Local Reliability**: Local on-device Whisper inference (`whisper.cpp`) with CoreML acceleration, fully operational offline without mandatory cloud dependencies.

## Considered Options
1. **Retain All Languages and Hide in UI**: Keep the full multi-language registry but filter in views.
2. **Comprehensive Pruning & First-Class Bilingual Specialization (Selected)**: Prune unneeded languages across configuration, localization, model catalogs, and prompts, leaving clean, maintainable code dedicated to English and Portuguese.

## Decision Outcome
Chosen option: **Option 2 (Comprehensive Pruning & First-Class Bilingual Specialization)**.

### Scope of Changes:
1. **Identity & Rebranding**:
   - Rebrand user-facing display names, bundle identifiers, and menu bar entries to **Sonotype**.
2. **Localization & UI Strings**:
   - `AppLanguagePreference.swift`: Restrict bundled language identifiers to `["en", "pt-PT", "pt-BR"]`.
   - `Localizable.xcstrings` and `InfoPlist.xcstrings`: Remove German, French, and Chinese; provide complete translations in Portuguese (`pt`, `pt-PT`, `pt-BR`).
3. **Speech-to-Text Language Catalogs**:
   - `LanguageDictionary.swift`: Prune the `all` and `whisperLanguageCodes` lists to English, Portuguese, and `auto`.
   - `TranscriptionModelRegistry.swift`: Prioritize multilingual models with strong PT/EN performance (`whisper`, `nativeApple`, `nemotronLatin`).
4. **AI Enhancement Prompts & Hesitations**:
   - `FillerWordManager.swift`: Seed default hesitation words with both English (`uh`, `um`) and Portuguese (`hum`, `é`, `tipo`, `ãh`).
   - `AIPrompts.swift` & `PromptTemplates.swift`: Calibrate system instructions for proper PT/EN sentence structures and capitalization.

## Pros and Cons of the Decision
* **Good, because**: Codebase complexity and size are drastically reduced.
* **Good, because**: UI language selection is clean and uncluttered.
* **Good, because**: Portuguese users get a 100% native experience rather than an afterthought.
* **Bad, because**: Users desiring other languages (e.g., Spanish or French) cannot use Sonotype without restoring their respective models and localizations.
