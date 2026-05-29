# Product Roadmap
> **Last updated: 2026-05-29**
> Implementation status, planned features, and deprecation details.

---

## 🚦 Release Phases & Status

OpenAssistant has completed its core transition to the **OpenAI Assistants API v2** and is currently in a **Stable Maintenance Mode**. Critical security patches and compatibility updates with new OpenAI model families (such as the o-series) are prioritized.

### Phase 1: Core Client Foundations (v1.0)
- [x] Native SwiftUI tab-based layout and base navigation controllers.
- [x] Secure local configuration of OpenAI API Key via `@AppStorage`.
- [x] Base client networking layer using `URLSession` data tasks.
- [x] Basic thread creation, run invocation, and message retrieval.
- [x] User appearance configuration (Light, Dark, and System modes).

### Phase 2: Vector Stores & File Ingestion (v1.5)
- [x] Vector Store lifecycle CRUD management.
- [x] Association of Vector Stores to specific Assistants.
- [x] Multipart/form-data file upload pipeline with boundaries.
- [x] On-device file processor conversions:
  - [x] HEIC image to JPEG conversion.
  - [x] RTF text documents to plain text (`.txt`).
  - [x] Audio and video files to text transcriptions (placeholder).
- [x] Static chunking strategy configuration (max chunk size & overlap tokens).
- [x] Local message persistence cache via JSON serialization in `MessageStore`.

### Phase 3: Assistants API v2 & Reasoning Models (v2.0)
- [x] Upgraded client to target `OpenAI-Beta: assistants=v2`.
- [x] Centralized model capability checking (`ModelCapabilities.swift`).
- [x] Support for O-Series Reasoning Models:
  - [x] Auto-detection of `o1`, `o3`, `o4` prefixes.
  - [x] Exclude unsupported `temperature` and `top_p` parameters for reasoning models.
  - [x] Inject `reasoning_effort` configurations for reasoning models.
- [x] Transient network error retry mechanism (exponential backoff).
- [x] Decoupled state updates using `NotificationCenter` broadcasts.

### Phase 4: Security & Quality of Life (Planned)
- [ ] **Keychain Integration:** Migrate the OpenAI API Key from `UserDefaults` (`@AppStorage`) to Apple's Keychain Services with Face ID / Touch ID validation constraints.
- [ ] **SSE Streaming:** Replace polling timer runs with Server-Sent Events (SSE) streaming for real-time text generation updates.
- [ ] **Whisper Integration:** Replace on-device audio transcription placeholders with direct calls to OpenAI's Whisper API.
- [ ] **Markdown copy utility:** Add a copy-to-clipboard button for code blocks rendered in the chat bubble.
- [ ] **Dynamic models filtering:** Auto-filter out text-embedding or non-assistant models in the dropdown.

---

## ⚠️ Deprecations & Legacy Paths

- **Assistants API v1:** Fully deprecated due to OpenAI's migration requirements. The header `assistants=v1` has been removed.
- **Hardcoded Model Lists:** Replaced by dynamic model lists queried from the `/v1/models` API endpoint.
- **UserDefaults API Key plain text:** Flagged as a security improvement target (to be moved to Keychain in Phase 4).
- **Legacy Completions API:** The app does not support standard chat completions (use custom assistants or the new `/v1/responses` engine instead).
