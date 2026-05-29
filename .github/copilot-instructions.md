# OpenAssistant iOS Client Developer Copilot Instructions

## 📍 1. Project Identity

**OpenAssistant** is a native iOS client built in SwiftUI that interacts directly with the stateful **OpenAI Assistants API (v2)**. The application implements an MVVM-S architecture to cleanly separate UI presentation, reactive business controllers, and async networking. It features an on-device document preprocessing strategy pipeline to convert media formats locally before transmission, and orchestrates stateful run executions via safe timer status polling.

---

## 🎯 2. Prime Directives

- **Adhere strictly to verified facts**: Never assume, guess, or invent APIs, files, or completed capabilities. If a detail cannot be verified by scanning the codebase, mark it as `Needs verification`.
- **Maintain Design Patterns**: Ensure any additions conform to the established MVVM-S framework, MainActor VM pinning, base class inheritance, and event synchronization patterns.
- **Maintain Document Integrity**: Keep all file headers, copyright symbols, and code documentation intact unless explicitly instructed otherwise.

---

## 🏗️ 3. Architecture Rules

- **ViewModels**: All ViewModels must reside in `OpenAssistant/MVVMs/` and inherit from `BaseViewModel` or `BaseAssistantViewModel` located in `OpenAssistant/MVVMs/Bases/`.
- **MainActor Pinning**: ViewModels must be annotated with `@MainActor` to prevent multi-threading UI mutations.
- **Unidirectional Flow**: Views must never contact networking services directly. They must only invoke methods on ViewModels and observe published changes.
- **Decoupled Notification Bus**: Coordinate data updates across views via `NotificationCenter` using the custom notifications defined in `Main/Extensions.swift`. Do not establish direct delegation or references between Tab ViewModels.
- **Strategy Pattern for Ingestion**: Place any file processing logic inside a strategy class implementing `FileConversionStrategy` in `FileUploadService.swift`.

---

## 🗂️ 4. Key Files by Concern

- **App Entry**: [OpenAssistantApp.swift](OpenAssistant/Main/OpenAssistantApp.swift) (bootstrapping, environment inject).
- **Core Models**: [OpenAIService-Threads.swift](OpenAssistant/APIService/OpenAIService-Threads.swift) (e.g. `Message`, `Thread`, `Run`).
- **Main Services**: [OpenAIService.swift](OpenAssistant/APIService/OpenAIService.swift) (base networking, retry backoff logic).
- **Ingestion/Conversions**: [FileUploadService.swift](OpenAssistant/MVVMs/VectorStores/Files/FileUploadService.swift) (strategies, multipart form builders).
- **Storage/Persistence**: [MessageStore.swift](OpenAssistant/MVVMs/Chat/ChatParts/MessageStore.swift) (UserDefaults JSON history cache).

---

## ⚙️ 5. Build and Test Commands

- **Build Package Validation**:
  ```bash
  swift build
  ```
- **Xcode Command-Line Build (No Signing)**:
  ```bash
  xcodebuild -workspace OpenAssistant.xcworkspace -scheme OpenAssistant -sdk iphonesimulator build CODE_SIGNING_ALLOWED=NO
  ```
- **Local Dev Setup**:
  ```bash
  chmod +x setup.sh
  ./setup.sh
  ```

---

## 🧼 6. Logging and Debugging Conventions

- **Console Logging**: Use `print()` statement macros for detailed execution diagnostics, tracking serialized request bodies, response payloads, and polling ticks.
- **No Production Key Logging**: Ensure raw API tokens, credential variables, or decryption logs are never written to the console in release configurations.
- **Error Presentation**: Intercept failures using the `OpenAIServiceError` enum and map them to UI alert dialogs using the base helper `IdentifiableError`.

---

## 🔒 7. Security and Data sovereignty Rules

- **Credential Safety**: Always store API keys in `UserDefaults` (`@AppStorage("OpenAI_API_Key")`) locally. Never hardcode credentials in code blocks or configuration parameters.
- **Purge Temporary Files**: Ensure any media binaries written to `tmp/` during conversions are deleted immediately after the network transaction completes.
- **TLS Enforcements**: Do not bypass App Transport Security (ATS) rules. Only TLS 1.3/1.2 connections to OpenAI are allowed.

---

## 📖 8. Documentation Update Rules

- **Keep Specs Aligned**: If you add new parameters, files, or endpoints, update the following files:
  - `README.md` (overview and tables)
  - `ARCHITECTURE.md` (concurrency diagrams, APIs)
  - `docs/CASE_STUDY.md` (engineering challenges and solutions)
- **Repo-Relative Links**: All markdown links must use repo-relative paths (`[README.md](README.md)`) and never absolute local machine paths (`file:///Users/...`).
