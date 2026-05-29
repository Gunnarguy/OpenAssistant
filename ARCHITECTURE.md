# Architecture Specification
> **Last updated: 2026-05-29**
> System blueprint detailing design patterns, component relationships, tech stacks, and API specifications.

---

## 🏗️ Design Patterns & Data Flow Conventions

OpenAssistant utilizes the **MVVM-S (Model-View-ViewModel-Service)** architecture, structured to ensure a unidirectional data flow and isolate concerns:

1. **Unidirectional Data Flow:**
   - **View** captures user events and invokes functions on the **ViewModel**.
   - **ViewModel** updates its `@Published` state variables or executes calls to the **Service Layer** and reflects updates to the View.
   - **Service Layer** makes HTTP requests to remote APIs or updates local databases, propagating results back to the ViewModels via closures, Futures, or publishers.

2. **Decoupled Notification Bus:**
   - Cross-module communication relies on `NotificationCenter`. When data changes (e.g., an assistant is created/updated/deleted or a vector store is modified), the modifying ViewModel publishes a notification.
   - Subscribing ViewModels listen to these broadcasts, triggering cache resets or fetching fresh lists. This avoids direct references between ViewModels (e.g., `AssistantManagerViewModel` doesn't need to reference `VectorStoreManagerViewModel`).

3. **Concurrency Strategy:**
   - ViewModels are pinned to the `@MainActor` to guarantee UI changes execute on the main run loop.
   - Networking and file conversion strategies operate asynchronously using `async/await` and Combine publishers, executing work off the main thread.

---

## 🗂️ Component Breakdown Table

The following table maps the core application classes to their responsibilities, architectural roles, and dependencies:

| Class / File | Role | Patterns Used | Key Dependencies |
| :--- | :--- | :--- | :--- |
| `OpenAssistantApp` | App Entry Point | Core Orchestrator | `FirebaseCore`, `ContentView` |
| `OpenAIService` | Base API Client | Singleton (via Initializer), Extensions | `URLSession` |
| `FileUploadService` | File Uploader | Coordinator Service | `URLSession`, `FileProcessor` |
| `FileProcessor` | File Type Converter | Strategy Pattern | `AVFoundation`, `UIKit` |
| `MessageStore` | Local Persistence Store | Repository, ObservableObject | `UserDefaults`, `JSONEncoder/Decoder` |
| `ChatViewModel` | Chat Controller | ObservableObject ViewModel | `OpenAIService`, `MessageStore` |
| `AssistantManagerViewModel` | Assistant Controller | ObservableObject ViewModel | `OpenAIService` |
| `VectorStoreManagerViewModel` | Vector Store Controller | ObservableObject ViewModel | `OpenAIService`, `URLSession` |

---

## 🛠️ Technology Stack & Integrations

| Framework / Service | Scope | Integration Method | Purpose |
| :--- | :--- | :--- | :--- |
| **SwiftUI** | Native UI | Apple SDK | Declarative layout composition and styling. |
| **Combine** | Reactive Bindings | Apple SDK | Binding ViewModel publishers to declarative views. |
| **URLSession** | Networking | Apple SDK | Transport layer for OpenAI HTTP requests. |
| **Firebase Core** | Mobile Lifecycle | CocoaPods | Application telemetry and configuration. |
| **Firebase Analytics** | Crash Reporting / Metrics | CocoaPods | Crash diagnostics and release telemetry. |
| **UniformTypeIdentifiers** | File Type Verification | Apple SDK | Validating system MIME types during ingestion. |
| **AVFoundation** | Media Processing | Apple SDK | Validating local audio/video durations and extensions. |

---

## 📡 Discovered API Specifications

All network interactions pass through `OpenAIService` directly to the OpenAI API endpoints. The app uses the `assistants=v2` beta header.

### Request Headers
```http
Authorization: Bearer <API_KEY>
Content-Type: application/json (or multipart/form-data for file uploads)
OpenAI-Beta: assistants=v2
```

### Endpoints Catalog

#### 1. Assistants Management
- **Fetch Assistants List:**
  - `GET /v1/assistants`
  - Returns `AssistantsResponse` containing a list of `Assistant` objects.
- **Get Assistant Details:**
  - `GET /v1/assistants/{id}`
  - Returns the requested `Assistant` object.
- **Create Assistant:**
  - `POST /v1/assistants`
  - Body: JSON containing details like `model`, `name`, `description`, `instructions`, `tools`, `tool_resources`, `temperature`, `top_p`, `reasoning_effort`, `response_format`.
  - Returns the created `Assistant` object.
- **Update Assistant:**
  - `POST /v1/assistants/{id}`
  - Body: JSON dictionary containing fields to update.
- **Delete Assistant:**
  - `DELETE /v1/assistants/{id}`
  - Returns standard delete confirmation.

#### 2. Vector Stores & Files
- **Create Vector Store:**
  - `POST /v1/vector_stores`
  - Body: `{"name": "<STORE_NAME>"}`
- **List Vector Stores:**
  - `GET /v1/vector_stores`
- **Get Vector Store Details:**
  - `GET /v1/vector_stores/{id}`
- **Delete Vector Store:**
  - `DELETE /v1/vector_stores/{id}`
- **Add File to Vector Store Batch:**
  - `POST /v1/vector_stores/{id}/file_batches`
  - Body: `{"file_ids": ["<FILE_ID>"], "chunking_strategy": {"type": "static", "static": {"max_chunk_size_tokens": Int, "chunk_overlap_tokens": Int}}}`
- **Get File Batch Details:**
  - `GET /v1/vector_stores/{id}/file_batches/{batch_id}`
- **List Files in Vector Store:**
  - `GET /v1/vector_stores/{id}/files`
- **Delete File from Vector Store:**
  - `DELETE /v1/vector_stores/{vector_store_id}/files/{file_id}`
- **Upload File to OpenAI:**
  - `POST /v1/files`
  - Content-Type: `multipart/form-data`
  - Parts: `purpose="assistants"`, `file=<binary_data>`
- **Delete File from OpenAI:**
  - `DELETE /v1/files/{id}`

#### 3. Thread & Session Control
- **Create Chat Thread:**
  - `POST /v1/threads`
- **Get Thread Details:**
  - `GET /v1/threads/{id}`
- **Add Message to Thread:**
  - `POST /v1/threads/{id}/messages`
  - Body: `{"role": "user", "content": [{"type": "text", "text": "<TEXT_VALUE>"}]}`
- **Run Assistant on Thread:**
  - `POST /v1/threads/{id}/runs`
  - Body: `{"assistant_id": "<ASSISTANT_ID>"}`
- **Fetch Run Status:**
  - `GET /v1/threads/{id}/runs/{run_id}`
- **Fetch Thread Messages:**
  - `GET /v1/threads/{id}/messages`

#### 4. Advanced Responses API
- **Create Custom Response:**
  - `POST /v1/responses`
  - Body: `ResponseRequest` JSON containing parameters like `model`, `input`, `max_output_tokens`, `stream`.
- **Retrieve Custom Response:**
  - `GET /v1/responses/{response_id}`
