# Product Roadmap
> **Last updated: May 29, 2026**
<p align="center">
  <strong>Development status, completed milestones, active work, planned features, technical debt, and release checklists.</strong>
</p>

---

## 🚦 1. Current Status

OpenAssistant has completed its core migration to the **OpenAI Assistants API (v2)** and is in **Active Development Status**. The application compiles on Xcode 15.0+ and operates on iOS 15.0+ devices. Development focuses on security hardening, adding automated testing coverage, and improving audio ingestion workflows.

---

## 🏆 2. Completed Milestones

### Phase 1: Core Client Foundations (v1.0)
- [x] Native SwiftUI tab-based UI layout and navigation controllers.
- [x] Secure local configuration of OpenAI API Key via `@AppStorage`.
- [x] Base client networking layer using `URLSession` data tasks.
- [x] Base thread creation, run invocation, and status checking.
- [x] Dark, Light, and System appearance mode support.

### Phase 2: Vector Stores & Local Preprocessing (v1.5)
- [x] Vector Store lifecycle CRUD management.
- [x] Local multipart form data uploader with boundaries.
- [x] On-device file processor conversions:
  - [x] HEIC graphics to JPEG format.
  - [x] RTF documents to plain UTF-8 text (`.txt`).
  - [x] Audio and video files to text transcriptions (placeholder).
- [x] Configuration of static chunking strategies (max chunk size & overlap tokens).
- [x] Local chat message persistence cache via JSON serialization in `MessageStore`.

### Phase 3: Assistants API v2 & Reasoning Models (v2.0)
- [x] Upgraded client header targeting `OpenAI-Beta: assistants=v2`.
- [x] Dynamic model capability checking for o-series reasoning models.
- [x] Adaptive configurations (excluding temperature/Top-P and injecting reasoning effort) for o-series model runs.
- [x] Exponential backoff retry logic for transient URLSession network failures.
- [x] Decoupled state updates using `NotificationCenter` broadcasts.

---

## 🚧 3. Active Work

- **Documentation Overhaul**: Audit and upgrade all project documentation to professional, portfolio-grade specifications with clean Mermaid diagrams.
- **Git Security Hooks**: Integrate automated hooks rejecting commits containing raw API keys to protect developers from accidental credential exposure.

---

## 🚀 4. Planned Improvements

- **Keychain Integration**: Migrate the OpenAI API Key from plain `UserDefaults` to Apple's Keychain Services with Face ID / Touch ID validation constraints.
- **Whisper Integration**: Replace on-device audio transcription placeholders with direct calls to OpenAI's Whisper API.
- **SSE Streaming**: Support Server-Sent Events (SSE) streaming for real-time text generation bubbles instead of 2.0s polling timers.
- **Markdown Copy Utility**: Add a copy-to-clipboard button for code blocks rendered in the chat bubbles.

---

## ⚠️ 5. Known Limitations & Technical Debt

### Limitations
- **Active Polling Overhead**: Querying run status via REST polling increases cellular battery drain.
- **Lack of Local Search**: No local vector or lexical search indexing is done; all semantic search queries rely on OpenAI vector stores.

### Technical Debt
- **Zero Unit Test Coverage**: The project contains no active XCTest suites, leaving state synchronization and file processors unverified.
- **AudioTranscription Strategy Placeholder**: Audio files picked for uploads do not extract actual transcriptions, relying on temporary placeholder strings.

---

## 📋 6. Release Readiness Checklist

Before tagging a production/release version of OpenAssistant:
- [ ] **Secret Scan**: Run the pre-commit hook scanning command to ensure no developer keys are in configuration plist/assets files.
- [ ] **Build Validation**: Verify that the workspace builds successfully without errors for both Simulator and physical iOS target SDKs.
- [ ] **Onboarding Check**: Verify the app redirects users to the Settings panel if the OpenAI API Key is missing.
- [ ] **Lifecycle Check**: Verify that polling timers terminate properly upon deinitialization of the Chat window to prevent memory leaks.
- [ ] **Licensing Check**: Verify the MIT License is correctly linked and packaged in the build payload.
