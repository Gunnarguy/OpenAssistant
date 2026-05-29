# OpenAssistant (iOS Client)
> **Last updated: 2026-05-29**
> Native SwiftUI client for the OpenAI Assistants API. Optimized for iOS 15.0+.

<p align="center">
  <img src="https://img.shields.io/badge/Swift-F05138.svg?style=for-the-badge&logo=Swift&logoColor=white" alt="Swift" />
  <img src="https://img.shields.io/badge/SwiftUI-007AFF.svg?style=for-the-badge&logo=SwiftUI&logoColor=white" alt="SwiftUI" />
  <img src="https://img.shields.io/badge/Combine-007AFF.svg?style=for-the-badge&logo=Combine&logoColor=white" alt="Combine Framework" />
  <img src="https://img.shields.io/badge/OpenAI%20API-412991.svg?style=for-the-badge&logo=OpenAI&logoColor=white" alt="OpenAI API" />
</p>

---

## 📍 Overview

**OpenAssistant** is a native iOS client built using **SwiftUI** and the **Combine framework**. It provides a mobile dashboard for interacting with the **OpenAI Assistants API (v2)**. The app enables users to securely manage their custom AI assistants, thread histories, and vector store knowledge bases directly from their iPhone or iPad.

By utilizing on-device processing, OpenAssistant performs local file format conversions (HEIC-to-JPEG, RTF-to-TXT, and audio transcription placeholders) before upload, bypassing OpenAI's format limitations and saving bandwidth. It enforces data sovereignty by persisting API credentials exclusively in Apple's local user storage and calling OpenAI's servers directly without intermediate proxies.

---

## 🗺️ End-to-End User Journey

The flowchart below maps the user journey from launching the app, entering credentials, managing resources, to executing runs and retrieving AI outputs.

```mermaid
graph TD
    A[Launch App] --> B{API Key Configured?}
    B -- No --> C[Display Settings View]
    C --> D[User Enters OpenAI API Key]
    D --> E[Save Settings & Post .settingsUpdated]
    E --> F[Initialize OpenAIService]
    B -- Yes --> F
    
    F --> G[MainTabView Dashboard]
    
    %% User Actions
    G --> H[Create / Configure Assistant]
    G --> I[Manage Vector Stores & Ingest Files]
    G --> J[Select Assistant & Open Chat]
    
    %% Ingest Flow
    I --> I1[Select Local Document / Photo]
    I1 --> I2[On-device Format Conversion]
    I2 --> I3[Upload to OpenAI / Vector Store]
    I3 --> H
    
    %% Chat Flow
    H --> J
    J --> K[User Sends Message]
    K --> K1[Create Message & Persist to MessageStore]
    K1 --> K2[POST Message to Thread]
    K2 --> L[Run Assistant on Thread]
    L --> M[Poll Run Status every 2.0s]
    M --> N{Status Completed?}
    N -- No / Queued --> M
    N -- Yes --> O[Fetch Run Messages]
    O --> P[Deduplicate & Save to MessageStore]
    P --> Q[Render Markdown Chat Output]
```

---

## 🏗️ System Architecture

OpenAssistant utilizes the **MVVM-S (Model-View-ViewModel-Service)** pattern to isolate responsibilities and establish a unidirectional data flow.

```mermaid
graph TD
    subgraph Views [SwiftUI Declarative Views]
        V_Tab[MainTabView]
        V_Chat[ChatView]
        V_Detail[AssistantDetailView]
        V_Vector[VectorStoreListView]
        V_Settings[SettingsView]
    end

    subgraph ViewModels [Reactive Business Logic]
        VM_Base[BaseViewModel]
        VM_Chat[ChatViewModel]
        VM_Asst[AssistantManagerViewModel]
        VM_Vector[VectorStoreManagerViewModel]
    end

    subgraph Services [API & Persistence Layer]
        S_Init[OpenAIInitializer]
        S_API[OpenAIService]
        S_Upload[FileUploadService]
        P_Message[MessageStore]
        P_Storage["@AppStorage (Preferences)"]
    end

    subgraph External [APIs]
        E_OpenAI[OpenAI Assistants API]
        E_Firebase[Firebase Analytics & Crashlytics]
    end

    %% View to VM bindings
    V_Tab --> VM_Chat
    V_Chat --> VM_Chat
    V_Detail --> VM_Asst
    V_Vector --> VM_Vector
    V_Settings --> P_Storage
    
    VM_Chat -- Inherits --> VM_Base
    VM_Asst -- Inherits --> VM_Base
    VM_Vector -- Inherits --> VM_Base
    
    %% VM to Service interactions
    VM_Base -.-> S_API
    VM_Chat <--> P_Message
    VM_Vector -.-> S_Upload
    S_Upload -.-> S_API
    
    %% Service to API
    S_API --> E_OpenAI
    S_Upload --> E_OpenAI
    V_Tab --> E_Firebase
```

---

## 🌊 Core Pipelines

### 1. On-Device File Ingestion & Conversion
The app converts unsupported files locally to standard, OpenAI-compatible types before upload.

```mermaid
flowchart TD
    Start[User selects file for Vector Store] --> DetectExtension{Detect Extension}
    
    %% Extension Routing
    DetectExtension -- directly supported --> UploadRaw[Read raw bytes & filename]
    DetectExtension -- heic --> HEICConv[HEICToJPEGStrategy: Convert UI/CGImage to JPEG]
    DetectExtension -- rtf --> RTFConv[RTFToTXTStrategy: Parse NSAttributedString to Plain UTF-8]
    DetectExtension -- m4a/mp3/wav/mp4/mov --> AudioConv[AudioTranscriptionStrategy: Placeholder for transcription]
    DetectExtension -- other text --> TextConv[UTF-8/ASCII plain text fallback]
    DetectExtension -- unrecognized binary --> Error[Throw unsupportedFileType Error]

    HEICConv --> UploadRaw
    RTFConv --> UploadRaw
    AudioConv --> UploadRaw
    TextConv --> UploadRaw
    
    UploadRaw --> Multipart[Generate Boundary & build multipart/form-data]
    Multipart --> POSTFile[POST /v1/files]
    POSTFile --> FileID[Receive File ID]
    FileID --> BatchPOST[POST /v1/vector_stores/:id/file_batches]
    BatchPOST --> Success[File Indexed in Vector Store]
```

### 2. Thread Run Execution & Status Polling
Managing the multi-step lifecycle of OpenAI Assistants thread executions.

```mermaid
flowchart TD
    UserMsg[User Types Text & clicks Send] --> LocalSave[Create Local Message & append in natural order]
    LocalSave --> LocalStore[Deduplicate & save to MessageStore]
    LocalStore --> APIAdd[POST /v1/threads/:id/messages]
    APIAdd --> APIRun[POST /v1/threads/:id/runs]
    APIRun --> Polling[Start 2.0s Polling Timer]
    Polling --> GETStatus[GET /v1/threads/:id/runs/:run_id]
    GETStatus --> StatusEval{Evaluate Run Status}
    
    StatusEval -- queued / in_progress --> Polling
    StatusEval -- failed / cancelled --> Error[Display UI Error & Stop Timer]
    StatusEval -- completed --> StopTimer[Invalidate Polling Timer]
    
    StopTimer --> GETMsgs[GET /v1/threads/:id/messages]
    GETMsgs --> SaveMsgs[Filter Role=assistant, save to MessageStore]
    SaveMsgs --> UIRefresh[Update local Messages & scroll UI to bottom]
```

---

## 🗃️ Configuration Catalog

The application maintains the following keys and configurations:

| Key | Type | Default | Storage Location | Description |
| :--- | :--- | :--- | :--- | :--- |
| `OpenAI_API_Key` | String | `""` | `UserDefaults` (via `@AppStorage`) | Secure OpenAI Authentication Token. Required to establish connection. |
| `appearanceMode` | String | `"System"` | `UserDefaults` (via `@AppStorage`) | Appearance theme value. Supported values: `"Light"`, `"Dark"`, `"System"`. |
| `savedMessages` | Data | `nil` | `UserDefaults` (via `@AppStorage`) | JSON-serialized message history list mapped by thread IDs. |
| `enableNewFeature` | Boolean | `false` | Compile-time constant (`FeatureFlags.swift`) | Gatekeeper flag to isolate incomplete experimental structures in production builds. |

---

## 🛠️ Developer Onboarding

### Local Environment Setup
To build and run OpenAssistant locally, complete the following steps:

1. **Clone the Repository:**
   ```bash
   git clone https://github.com/Gunnarguy/OpenAssistant.git
   cd OpenAssistant
   ```
2. **Execute the Setup Helper Script:**
   The script checks prerequisites, configures local dependencies, and installs Git pre-commit hooks to safeguard OpenAI keys:
   ```bash
   ./setup.sh
   ```
3. **Select Development Team:**
   - Open `OpenAssistant.xcworkspace` in Xcode 15+.
   - Navigate to the project settings, select the **OpenAssistant** target.
   - Under **Signing & Capabilities**, select your Apple Developer Team and customize the Bundle Identifier.
4. **Build and Run:**
   - Connect an iOS 15.0+ physical device or select a simulator (e.g., iPhone 17 Pro Max).
   - Press `⌘+R` to build and launch the application.

---

## 📖 Documentation Index

| File | Path | Description |
| :--- | :--- | :--- |
| **README** | [README.md](README.md) | High-level system overview, visual journeys, architecture, and onboarding. |
| **Architecture Specification** | [ARCHITECTURE.md](ARCHITECTURE.md) | Component breakdown, detailed design patterns, tech stack, and API specs. |
| **Product Roadmap** | [ROADMAP.md](ROADMAP.md) | Feature matrix, release phases, and project maintenance milestones. |
| **Security Guidelines** | [SECURITY.md](SECURITY.md) | Security assertions, secrets management, and pre-commit scan rules. |
| **Privacy Compliance** | [PRIVACY.md](PRIVACY.md) | Data residency, on-device sandboxing, and network transmission disclosures. |
| **App Store connect** | [APP_STORE.md](APP_STORE.md) | Reviewer credentials, test credentials, and step-by-step test paths. |
| **Case Study** | [docs/CASE_STUDY.md](docs/CASE_STUDY.md) | Narrative detailing technical challenges solved, concurrency, and architecture. |
