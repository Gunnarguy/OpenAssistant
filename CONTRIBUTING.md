# Contributing to OpenAssistant
<p align="center">
  <strong>Development prerequisites, branching workflows, coding conventions, and AI-agent contribution rules.</strong>
</p>

---

## 📍 1. Project Status & Vision

OpenAssistant is an active native iOS/SwiftUI application. We welcome contributions that improve features, upgrade stability, and maintain clean architectural compliance with our **MVVM-S** design patterns.

---

## 🛠️ 2. Development Prerequisites & Setup

### Requirements
- **macOS** with Xcode 15.0+
- **iOS 15.0+** deployment target
- **CocoaPods** installed (`brew install cocoapods` or ruby gem)
- A valid **OpenAI API Key** for runtime testing

### Local Installation
1. **Clone the Repository**:
   ```bash
   git clone https://github.com/Gunnarguy/OpenAssistant.git
   cd OpenAssistant
   ```
2. **Execute the Setup Script**:
   Installs CocoaPods dependencies and configures local git pre-commit security hooks:
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
3. **Configure signing in Xcode**:
   - Open `OpenAssistant.xcworkspace` in Xcode.
   - Select the **OpenAssistant** target.
   - Under **Signing & Capabilities**, choose your Development Team and update the Bundle Identifier to avoid conflicts.

---

## 🗺️ 3. Branching & Commit Workflows

### Branch Naming Conventions
Follow structured prefixes when creating branches:
- `feature/` for new capabilities (e.g. `feature/keychain-storage`)
- `bugfix/` for resolving issues (e.g. `bugfix/polling-timer-memory-leak`)
- `docs/` for documentation adjustments (e.g. `docs/update-architecture`)
- `refactor/` for non-functional cleanup (e.g. `refactor/clean-models`)

### Commit Style
We advocate for **Conventional Commits**:
- `feat: <description>` (e.g. `feat: add RTF conversion strategy`)
- `fix: <description>` (e.g. `fix: resolve multi-tab list refresh bug`)
- `docs: <description>` (e.g. `docs: add key decisions table`)
- `refactor: <description>` (e.g. `refactor: remove redundant observers`)

---

## 🧱 4. Coding Conventions & Architecture Adherence

To maintain consistency, all contributions must respect the core design pattern:

### 1. MVVM-S Strict Isolation
- **Views**: SwiftUI files must only draw layouts. Never perform network operations or mutate app configuration state outside of binding UI state.
- **ViewModels**: Must inherit from `BaseViewModel` or `BaseAssistantViewModel` located in `OpenAssistant/MVVMs/Bases/`. Tag ViewModel definitions with `@MainActor` to guarantee thread safety.
- **Service Injection**: Use the `performServiceAction { service in ... }` helper inside ViewModels to trigger async API actions.

### 2. Event-Driven Sync
- Do not pass direct delegates or strong references between Tab ViewModels. Use `NotificationCenter` to publish events (e.g., `.assistantCreated`, `.vectorStoreUpdated`). ViewModels must listen to these notifications in `setupNotificationObservers()` to refresh their caches.

### 3. File Processing Strategies
- File conversions must implement `FileConversionStrategy` located in [FileUploadService.swift](OpenAssistant/MVVMs/VectorStores/Files/FileUploadService.swift). Execute processing off the main actor thread.

---

## 🤖 5. AI-Agent Contribution Rules

If you are an autonomous AI coding agent pair-programming on this codebase:
- **Do Not Invent Code/Files**: Only document or edit resources that are verified to exist in this codebase.
- **Data Exclusion Guardrails**: Never read, parse, or output configurations from `.env`, `.pem`, `.key`, or files containing private credentials. Mask any placeholder keys in responses using `[REDACTED_SECRET]`.
- **Maintain Diffs**: Propose diff modifications cleanly using code block replacements before applying modifications.
- **Update Documentation**: If your pull request introduces structural architectural changes (e.g., adding an API service or storage layer), you must update `ARCHITECTURE.md` and `README.md` to reflect the changes.

---

## 📋 6. Pull Request Checklist

Before submitting a Pull Request:
1. Verify the project builds cleanly without warnings using `⌘+B`.
2. Confirm the pre-commit hook runs successfully and no secrets are staged.
3. Test your code on an iOS simulator or physical device.
4. Verify that markdown links in your documentation changes are repo-relative.
5. Create a descriptive PR description matching [pull_request_template.md](.github/pull_request_template.md).
