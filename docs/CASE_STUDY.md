# Case Study: OpenAssistant iOS Client
> **Last updated: 2026-05-29**

---

## Abstract
OpenAssistant is a native SwiftUI application for iOS (iOS 15.0+) designed as a feature-rich, local-first client for the OpenAI Assistants API (v2). The application provides developers and power users with an intuitive mobile environment to manage AI assistants, inspect vector stores, and conduct document-based chat sessions. This case study details the architectural decisions, design patterns, and engineering challenges solved during its implementation—specifically focusing on on-device document ingestion, reactive state synchronization, and memory-safe asynchronous run polling.

---

## 1. Product Context & Motivation
The OpenAI Assistants API provides a stateful platform for running AI agents with retrieval-augmented generation (RAG) and code interpreter capabilities. However, integrating this API into a native mobile experience introduces distinct technical challenges:
- **Asynchronous Run Lifecycle:** Calls are stateful but asynchronous. Clients must execute multi-phase polling loops (Queued → In Progress → Completed) to retrieve AI outputs.
- **Strict Format Requirements:** The Assistants API rejects common mobile-captured formats (such as HEIC photographs or RTF documents) directly, forcing users to convert media files manually before upload.
- **Data Residency Concerns:** Storing API keys on remote proxy servers creates vulnerability vectors. Users require direct-to-destination connection models with on-device sandbox security.

OpenAssistant bridges these gaps by providing a client that performs format conversions on-device, manages message caching locally, and coordinates state via Apple's native framework ecosystems.

---

## 2. Core Architectural Decisions

### MVVM-S (Model-View-ViewModel-Service) Pattern
To isolate visual layouts from network models, the codebase strictly adheres to MVVM-S:
- **Views:** Declarative SwiftUI components (`ChatView`, `AssistantManagerView`, `VectorStoreDetailView`) that observe viewmodel states.
- **ViewModels:** Observables pinned to the `@MainActor` (e.g., `ChatViewModel`, `VectorStoreManagerViewModel`) that encapsulate reactive state variables.
- **Services:** Network engines (`OpenAIService` and its extensions) and uploader classes (`FileUploadService`) written in standard Swift.

### Decoupled Reactive Notifications
To synchronize data across independent views without tight coupling, the app implements an event bus using `NotificationCenter`. For example, when a user edits or deletes an assistant configuration in `AssistantDetailView`, the app posts an `.assistantCreated` or `.settingsUpdated` event. Observers in separate ViewModels intercept these events to clear local caches and refresh list items automatically:

```swift
private func setupVectorStoreObservers() {
    NotificationCenter.default.publisher(for: .vectorStoreUpdated)
        .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
        .sink { [weak self] _ in self?.initializeAndFetch() }
        .store(in: &cancellables)
}
```

---

## 3. Engineering Challenges & Solutions

### Challenge A: On-Device Document Ingestion & Strategy-Driven Conversion
**The Problem:** iOS users capture photos in HEIC format and document notes in RTF. The OpenAI Assistants API requires JPEG/PNG for visual inputs and TXT/PDF for search indices. Sending incompatible files causes network failures and breaks the ingestion pipeline.

**The Solution:** The app implements a Strategy Pattern to process files locally. A `FileConversionStrategy` protocol defines drop-in conversion behaviors:

```swift
protocol FileConversionStrategy {
    func convert(data: Data) throws -> (newData: Data, newExtension: String)
}
```

Concrete implementations handle conversions in memory before compiling the request:
- **HEICToJPEGStrategy:** Transforms HEIC graphics metadata to JPEG data using `UIImage.jpegData(compressionQuality:)`.
- **RTFToTXTStrategy:** Deconstructs Rich Text formats to plain UTF-8 text using `NSAttributedString` parsing.
- **AudioTranscriptionStrategy:** A modular target for voice-memo transcribing (currently mock-placed, routed for future Whisper endpoints).

The `FileProcessor` evaluates file extensions and dynamically routes the binary to the correct strategy. If a file is text-based but has a non-standard extension, it falls back to a plain text UTF-8 format. This architecture isolates the conversion rules from the `FileUploadService` networking code, allowing developers to extend format support without altering API transmission code.

### Challenge B: Memory-Safe Concurrency & Run Polling
**The Problem:** Querying the status of an assistant run requires active polling (sending GET requests every 2 seconds). Because network operations can outlive the view lifecycle, naive polling implementations can create strong reference cycles (retaining the ViewModel and View in memory after the user exits the chat) or spawn zombie network tasks.

**The Solution:** OpenAssistant implements a double-safeguard system to maintain concurrency and memory hygiene:
1. **Weak Self Captures:** Closure blocks in Combine pipelines and URLSession tasks explicitly capture `[weak self]` to allow memory release when the user navigates away.
2. **Explicit Timer Invalidation:** The polling loop uses a `Timer` registered on the main run loop. When a status is completed, failed, or when the viewmodel is deinitialized, the timer is explicitly invalidated:

```swift
private func checkRunStatus(threadId: String, runId: String, timer: Timer) {
    Task {
        do {
            let run = try await fetchRunStatus(threadId: threadId, runId: runId)
            await MainActor.run {
                self.handleRunStatus(run, timer: timer)
            }
        } catch {
            await MainActor.run {
                timer.invalidate()
                self.updateLoadingState(isLoading: false)
            }
        }
    }
}
```

---

## 4. Key Takeaways & Architecture Evaluation
1. **Unidirectional Bindings Simplify Testing:** Isolating network responses into clean Codable models and mapping them to `@Published` states allows viewmodels to be tested in mock environments without launching UIKit templates.
2. **On-Device Processing Saves Bandwidth:** Restructuring data formats locally before transmission reduces network payload size and prevents server-side API errors.
3. **Event-Driven Architectures Prevent Spaghetti Code:** Utilizing `NotificationCenter` publishers to synchronize list states across tabs keeps features modular, ensuring the assistant editor can run independently from the chat session views.
