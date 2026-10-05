# Implementation Plan: Sonotype Bilingual Specialization (EN & PT)

## Objective
Specialize the Sonotype application codebase to support exclusively **English and Portuguese** across interface localization, speech recognition catalogs, and AI enhancement prompts, while rebranding from VoiceInk to Sonotype.

---

## Tasks Breakdown

### Task 1: App Identity and Language Preference Configuration
- **Files**:
  - `VoiceInk/App/Configuration/AppLanguagePreference.swift`
  - `VoiceInk/App/Configuration/AppDefaults.swift`
- **Actions**:
  - Update `bundledLanguageIdentifiers` in `AppLanguagePreference.swift` to `["en", "pt-PT", "pt-BR"]`.
  - Ensure fallback language resolution defaults to English or Portuguese based on system locale.

### Task 2: String Catalogs Localization & Non-Target Language Pruning
- **Files**:
  - `VoiceInk/InfoPlist.xcstrings`
  - `VoiceInk/Localizable.xcstrings`
- **Actions**:
  - In `InfoPlist.xcstrings`, purge keys for `de`, `fr`, and `zh-Hans`. Add translations for `pt-PT` and `pt-BR` (or base `pt`).
  - In `Localizable.xcstrings`, clean out `de`, `fr`, and `zh-Hans`. Ensure all core user interface strings have accurate Portuguese translations.

### Task 3: Speech Language Dictionary & Selectors
- **Files**:
  - `VoiceInk/Features/ModelLibrary/Models/LanguageDictionary.swift`
  - `VoiceInk/Features/ModelLibrary/Components/LanguageSelectionView.swift`
- **Actions**:
  - In `LanguageDictionary.swift`, reduce `whisperLanguageCodes` to `["auto", "en", "pt"]`.
  - Reduce `appleNative` to English variants (`en-US`, `en-GB`, `en-CA`, `en-AU`) and Portuguese variants (`pt-PT`, `pt-BR`).
  - Reduce the general `all` dictionary to the curated list of English and Portuguese locale options.

### Task 4: Filler Words & AI Prompt Calibration
- **Files**:
  - `VoiceInk/Features/Enhancement/State/FillerWordManager.swift`
  - `VoiceInk/Core/Enhancement/AIPrompts.swift`
  - `VoiceInk/Features/Modes/Templates/StarterModeTemplate.swift`
- **Actions**:
  - Add standard Portuguese hesitation words to `defaultFillerWords` in `FillerWordManager.swift` (`"hum"`, `"é"`, `"tipo"`, `"ãh"`, `"ou seja"`).
  - Review `AIPrompts.swift` examples and task instructions to ensure bilingual punctuation and phrasing examples are provided.

### Task 5: Build Configuration & Verification
- **Files**:
  - `Makefile`
- **Actions**:
  - Verify build targets (`make whisper`, `make local`).
  - Prepare dependencies path check for `whisper.xcframework`.
