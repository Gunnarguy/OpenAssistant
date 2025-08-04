
<div align="center">
<h1 align="center">
<img src="https://raw.githubusercontent.com/PKief/vscode-material-icon-theme/ec559a9f6bfd399b82bb44393651661b08aaf7ba/icons/folder-markdown-open.svg" width="100" />
<br>
OpenAssistant (iOS Client)
</h1>
<h3 align="center">📍 A Native SwiftUI iOS Client for the OpenAI Assistants API</h3>
<h3 align="center"> Dive deep into an application designed for seamless interaction with powerful AI. This document provides an exhaustive guide to its architecture, components, and their intricate interactions.</h3>
<h3 align="center">⚙️ Developed with Swift & SwiftUI</h3>

<p align="center">
<img src="https://img.shields.io/badge/Swift-F05138.svg?style=for-the-badge&logo=Swift&logoColor=white" alt="Swift" />
<img src="https://img.shields.io/badge/SwiftUI-007AFF.svg?style=for-the-badge&logo=SwiftUI&logoColor=white" alt="SwiftUI" />
<img src="https://img.shields.io/badge/Combine-007AFF.svg?style=for-the-badge&logo=Combine&logoColor=white" alt="Combine Framework" />
<img src="https://img.shields.io/badge/OpenAI%20API-412991.svg?style=for-the-badge&logo=OpenAI&logoColor=white" alt="OpenAI API" />
</p>

<p align="center">
<img src="https://img.shields.io/badge/iOS-15.0+-blue?style=flat-square" alt="iOS 15.0+">
<img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="MIT License">
<img src="https://img.shields.io/github/issues/Gunnarguy/OpenAssistant?style=flat-square" alt="GitHub issues">
<img src="https://img.shields.io/github/stars/Gunnarguy/OpenAssistant?style=flat-square" alt="GitHub stars">
<img src="https://img.shields.io/github/forks/Gunnarguy/OpenAssistant?style=flat-square" alt="GitHub forks">
</p>
</div>

---

## 📚 Table of Contents

- [📍 Overview](#-overview)
- [✨ Key Features](#-key-features)
- [🚀 Quick Start](#-quick-start)
- [📖 Documentation](#-documentation)
- [🏗️ Architecture](#-architecture)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)

## 🚀 Quick Start

### Prerequisites
- iOS 15.0+ device
- Xcode 15+
- OpenAI API key

### Installation
```bash
git clone https://github.com/Gunnarguy/OpenAssistant.git
cd OpenAssistant
open OpenAssistant.xcodeproj
```

**Detailed setup instructions**: [docs/installation/INSTALLATION.md](docs/installation/INSTALLATION.md)

## � Documentation

All documentation is organized in the [`docs/`](docs/) directory:

- **[📖 Documentation Index](docs/README.md)** - Complete documentation overview
- **[�️ Installation Guide](docs/installation/INSTALLATION.md)** - Setup instructions
- **[🤝 Contributing](docs/contributing/CONTRIBUTING.md)** - How to contribute
- **[� Privacy Policy](docs/PRIVACY.md)** - Data handling information
- **[🏗️ Architecture Diagram](docs/interactions.html)** - Visual component interactions

---

## 📍 Overview

OpenAssistant is a feature-rich, native iOS application built meticulously with SwiftUI and the Combine framework. It serves as a sophisticated client for the OpenAI Assistants API, empowering users to harness the full potential of AI assistants directly from their Apple devices. The application offers comprehensive management of assistants, vector stores for retrieval, and file handling, all wrapped in an intuitive user interface. It is designed to handle the complexities of asynchronous API interactions, thread management, and local data persistence, providing a robust and user-friendly mobile experience.

---

## ✨ Key Features

| Feature | Description |
| :--- | :--- |
| **🤖 Assistant Lifecycle Management** | Create, view, meticulously configure (name, instructions, model selection including GPT-4o/4.1/O-series, description, temperature, top P, reasoning effort), and delete OpenAI Assistants. |
| **🛠️ Advanced Tool Configuration** | Dynamically enable or disable powerful tools for assistants, such as Code Interpreter and File Search (Retrieval). |
| **🗂️ Vector Store Operations** | Full CRUD (Create, Read, Update, Delete) for Vector Stores. Associate Vector Stores with Assistants to enable precise, file-based knowledge retrieval. |
| **📄 Comprehensive File Handling** | Upload various file types (PDF, TXT, DOCX, etc.) to OpenAI, associate them with specific Vector Stores using configurable chunking strategies (size and overlap). View detailed file metadata and manage files within these stores. |
| **💬 Dynamic Chat Interface** | Engage in interactive conversations with selected Assistants. Features include Markdown rendering for assistant responses, robust message history management (persisted locally via `MessageStore`), and OpenAI thread lifecycle control. |
| **🔄 Reactive UI & Data Sync** | Leverages the Combine framework for managing asynchronous operations and `NotificationCenter` for decoupled, real-time updates across the UI when assistants, stores, or settings change. |
| **🔑 Secure & Persistent API Key**| Securely stores and manages the OpenAI API key using `@AppStorage`, ensuring it persists across app sessions. |
| **🎨 Adaptive Appearance** | Supports Light, Dark, and System-defined appearance modes, configurable via in-app settings for a personalized user experience. |
| **📱 Native iOS Excellence** | Built from the ground up using SwiftUI, ensuring a modern, responsive, and platform-native user experience optimized for iOS. |
| **🏗️ Robust MVVM Architecture** | Organizes code using the Model-View-ViewModel (MVVM) pattern, promoting clear separation of concerns, enhanced testability, and superior maintainability. |
| **⚙️ Dedicated API Service Layer**| A specialized service layer (`APIService`) encapsulates all interactions with the OpenAI API, efficiently handling requests, responses, error conditions, and retries. |

---

## 🌟 Codebase Quality & Practices

| Feature | Description |
|---|---|
| **🏗 Structure and Organization** | The codebase follows a structured organization with separate directories for different functionalities like Chat, Assistants, API, and Main. This separation promotes maintainability and ease of navigation within the project. |
| **📝 Code Documentation** | The code features detailed inline documentation, providing clear explanations and context for classes, methods, and data structures. Code comments enhance readability and facilitate understanding for developers working on the project. |
| **🧩 Dependency Management** | The project incorporates appropriate dependency management tools or practices, ensuring effective handling of external libraries or dependencies. Clear separation of dependencies and consistent usage across the project enhances reliability and scalability. |
| **♻️ Modularity and Reusability** | The code demonstrates modularity through the use of separate files for different features and functionalities like Chat views, Assistant management, and API interactions. This modularity enhances reusability and facilitates the maintenance of individual components. |
| **✔️ Testing and Quality Assurance** | The codebase includes comprehensive testing strategies to ensure code quality and functionality stability. Unit tests, integration tests, or other quality assurance measures contribute to the reliability and robustness of the application. |
| **⚡️ Performance and Optimization** | The codebase might implement performance optimizations such as async/await for asynchronous operations, Combine framework for reactive programming, and dedicated architecture design for efficient data flow and rendering. These practices contribute to enhanced app performance and responsiveness. |
| **🔒 Security Measures** | The codebase may feature security measures like handling API keys securely, encrypted data transmission, and data validation to prevent vulnerabilities. Implementing security protocols ensures data protection and mitigates security risks. |
| **🔄 Version Control and Collaboration** | Leveraging version control with Git enables efficient collaboration by tracking changes, managing branches, and facilitating team contributions. Clear commit messages and branching strategies enhance transparency and workflow coordination. |
| **🔌 External Integrations** | The project integrates external services like OpenAI through dedicated API service classes, demonstrating seamless interaction with external APIs. Using clear interfaces and services for integrations ensures. |

---

## 📐 Architecture (MVVM)

The application is architected using the **Model-View-ViewModel (MVVM)** pattern, a cornerstone for building scalable and maintainable SwiftUI applications.

* **Model**: Represents the data structures and business logic. These are primarily Codable structs that mirror the OpenAI API entities (e.g., `Assistant`, `Message`, `Thread`, `Run`, `VectorStore`, `File`) and internal application data constructs.
* **View**: The UI layer, built declaratively with SwiftUI. Views observe ViewModels for state changes and render the UI accordingly. Examples: `ChatView`, `AssistantManagerView`, `VectorStoreDetailView`. They delegate user actions to their respective ViewModels.
* **ViewModel**: Acts as the bridge between the View and the Model. It prepares and provides data for the View, processes user input, manages UI state (e.g., loading indicators, error messages), and orchestrates operations by interacting with services (primarily `APIService`). Examples: `ChatViewModel`, `AssistantManagerViewModel`, `VectorStoreManagerViewModel`.

```mermaid
graph TD
    subgraph "User Interface (SwiftUI Views)"
        direction LR
        V_Chat[ChatView]
        V_AsstMgr[AssistantManagerView]
        V_AsstDetail[AssistantDetailView]
        V_VecStoreList[VectorStoreListView]
        V_VecStoreDetail[VectorStoreDetailView]
        V_Settings[SettingsView]
        V_Picker[AssistantPickerView]
        V_CreateAsst[CreateAssistantView]
        V_MainTab[MainTabView]
        V_Content[ContentView]
    end

    subgraph "ViewModels (State & Business Logic)"
        direction LR
        VM_Base[BaseViewModel]
        VM_BaseAsst[BaseAssistantViewModel] --- VM_Base
        VM_Content[ContentViewModel] --- VM_Base
        VM_Chat[ChatViewModel] --- VM_BaseAsst
        VM_AsstMgr[AssistantManagerViewModel] --- VM_BaseAsst
        VM_AsstDetail[AssistantDetailViewModel] --- VM_BaseAsst
        VM_AsstPicker[AssistantPickerViewModel] --- VM_BaseAsst
        VM_VecStoreMgr[VectorStoreManagerViewModel] --- VM_Base
    end

    subgraph "Services (API & File Handling)"
        direction LR
        S_OpenAI_Init[OpenAIInitializer]
        S_OpenAI[OpenAIService] -. Uses .-> S_OpenAI_Init
        S_OpenAI_AsstExt[OpenAIService-Assistant Ext.] -- Extends --> S_OpenAI
        S_OpenAI_ThreadExt[OpenAIService-Threads Ext.] -- Extends --> S_OpenAI
        S_OpenAI_VecExt[OpenAIService-Vector Ext.] -- Extends --> S_OpenAI
        S_FileUpload[FileUploadService] -. Uses .-> S_OpenAI
    end

    subgraph "Data Persistence & System Services"
        P_AppStorage["@AppStorage (API Key, Settings)"]
        P_MessageStore["MessageStore (Chat History)"]
        P_NotifCenter[NotificationCenter]
        P_Combine["Combine Framework"]
    end

    subgraph "External Dependencies"
        Ext_OpenAI_API[OpenAI API]
    end

    %% View to ViewModel (User Actions & Data Binding)
    V_Content --> VM_Content
    V_MainTab --> V_Picker
    V_MainTab --> V_AsstMgr
    V_MainTab --> V_VecStoreList
    V_MainTab --> V_Settings
    V_Picker --> VM_AsstPicker
    V_AsstMgr --> VM_AsstMgr
    V_AsstMgr --- V_CreateAsst
    V_AsstMgr --- V_AsstDetail
    V_CreateAsst --> VM_AsstMgr
    V_AsstDetail --> VM_AsstDetail
    V_VecStoreList --> VM_VecStoreMgr
    V_VecStoreDetail --> VM_VecStoreMgr
    V_Chat --> VM_Chat
    V_Settings --> P_AppStorage
    V_Settings -. Posts .-> P_NotifCenter

    %% ViewModel to Service (Requesting Data/Actions)
    VM_Base --> S_OpenAI
    VM_Chat -.-> S_OpenAI_ThreadExt
    VM_AsstMgr -.-> S_OpenAI_AsstExt
    VM_AsstMgr -.-> S_OpenAI_VecExt
    VM_AsstDetail -.-> S_OpenAI_AsstExt
    VM_AsstDetail -.-> VM_VecStoreMgr
    VM_AsstPicker -.-> VM_AsstMgr
    VM_VecStoreMgr -.-> S_OpenAI_VecExt
    VM_VecStoreMgr -.-> S_FileUpload

    %% Service to External API
    S_OpenAI --> Ext_OpenAI_API
    S_FileUpload --> Ext_OpenAI_API

    %% Data Flow & State Management
    P_MessageStore <--> VM_Chat
    P_AppStorage <--> VM_Base
    P_NotifCenter <--> VM_Base
    P_NotifCenter <--> VM_Content
    P_Combine <--> S_OpenAI
    P_Combine <--> VM_Base
    P_Combine <--> VM_VecStoreMgr


    classDef view fill:#B0E0E6,stroke:#4682B4,stroke-width:2px;
    classDef viewModel fill:#98FB98,stroke:#2E8B57,stroke-width:2px;
    classDef service fill:#FFA07A,stroke:#CD5C5C,stroke-width:2px;
    classDef persistence fill:#DDA0DD,stroke:#8A2BE2,stroke-width:2px;
    classDef external fill:#FFD700,stroke:#B8860B,stroke-width:2px;

    class V_Chat,V_AsstMgr,V_AsstDetail,V_VecStoreList,V_VecStoreDetail,V_Settings,V_Picker,V_CreateAsst,V_MainTab,V_Content view;
    class VM_Base,VM_BaseAsst,VM_Content,VM_Chat,VM_AsstMgr,VM_AsstDetail,VM_AsstPicker,VM_VecStoreMgr viewModel;
    class S_OpenAI_Init,S_OpenAI,S_OpenAI_AsstExt,S_OpenAI_ThreadExt,S_OpenAI_VecExt,S_FileUpload service;
    class P_AppStorage,P_MessageStore,P_NotifCenter,P_Combine persistence;
    class Ext_OpenAI_API external;
````

-----

## 📂 Detailed Project Structure

### iOS Project Source Code Structure

The project is organized into several directories, each serving a specific purpose. Here's a detailed breakdown:

<details>
<summary><strong>APIService (Networking & OpenAI Interaction)</strong></summary>

| File | Summary |
| :--- | :--- |
| CommonMethods.swift | Defines an extension on `OpenAIService` with methods for configuring and creating `URLRequest` objects. |
| FileUploadService.swift | Defines a `FileUploadService` class for uploading files to OpenAI and managing vector stores. |
| OpenAIInitializer.swift | Manages the initialization of the shared `OpenAIService` instance with thread safety. |
| OpenAIService-Assistant.swift | Extension for `OpenAIService` to manage assistants (CRUD operations). |
| OpenAIService-Threads.swift | Extension for `OpenAIService` to manage threads, runs, and messages. |
| OpenAIService-Vector.swift | Extension for `OpenAIService` to manage vector stores and files. |
| OpenAIService.swift | The main `OpenAIService` class for handling API requests, responses, and errors. |
| OpenAIServiceError.swift | Defines custom error types for `OpenAIService` operations. |

</details>

<details>
<summary><strong>Main Application Logic & Shared Components (Main/)</strong></summary>

| File | Summary |
| :--- | :--- |
| Additional.swift | Defines various data models used across the application. |
| Appearance.swift | Manages appearance-related settings (e.g., Light, Dark, System modes). |
| Errors.swift | Defines custom error types and error handling utilities. |
| LoadingView.swift | A SwiftUI view for displaying a loading indicator. |
| MainTabView.swift | The main tab view of the application. |
| ModelCapabilities.swift | Helper for checking the capabilities of different AI models. |
| OpenAssistantApp.swift | The main entry point of the SwiftUI application. |
| ResponseFormat.swift | Defines structs and enums for handling JSON response formats. |
| SettingsView.swift | A SwiftUI view for managing user settings. |
| Content/ContentView.swift | The root view of the application. |
| Content/ContentViewModel.swift | The view model for the `ContentView`. |

</details>

<details>
<summary><strong>MVVM Components (MVVMs/)</strong></summary>

| File | Summary |
| :--- | :--- |
| **Bases** | |
| BaseAssistantViewModel.swift | A base class for ViewModels related to Assistants. |
| BaseViewModel.swift | The primary base class for all ViewModels. |
| **Assistants Feature** | |
| AssistantDetailView.swift | SwiftUI view for managing an assistant's details. |
| AssistantDetailViewModel.swift | ViewModel for `AssistantDetailView`. |
| AssistantManagerView.swift | SwiftUI view for listing and managing assistants. |
| AssistantManagerViewModel.swift | ViewModel for `AssistantManagerView`. |
| AssistantPickerView.swift | SwiftUI view for selecting an assistant to start a chat. |
| AssistantPickerViewModel.swift | ViewModel for `AssistantPickerView`. |
| **Chat Feature** | |
| ChatView.swift | The main chat interface. |
| ChatViewModel.swift | Core chat logic and state management. |
| MessageStore.swift | Manages the persistence of chat messages. |
| **VectorStores Feature** | |
| VectorStoreDetailView.swift | Displays the details of a `VectorStore`. |
| VectorStoreListView.swift | Manages the list of vector stores. |
| VectorStoreManagerViewModel.swift | Manages all API interactions for vector stores. |
| AddFileView.swift | SwiftUI view for uploading files to a vector store. |

</details>

-----

## 🌊 Core Application & Data Flow

### 1\. App Initialization & Setup

The application starts with `OpenAssistantApp`, which sets up the main `ContentView` and injects essential environment objects like `AssistantManagerViewModel`, `VectorStoreManagerViewModel`, and `MessageStore`.

### 2\. API Key Management

The OpenAI API key is securely stored using `@AppStorage`. The application prompts the user for the key on first launch via the `SettingsView`. The `BaseViewModel` ensures that the `OpenAIService` is re-initialized whenever the key is updated.

### 3\. Main Navigation (`MainTabView`)

The `MainTabView` is the central navigation hub, providing access to the main features:

  - **Assistants**: Select an assistant for a chat (`AssistantPickerView`).
  - **Manage**: Create, edit, and delete assistants (`AssistantManagerView`).
  - **Vector Stores**: Manage vector stores and their files (`VectorStoreListView`).
  - **Settings**: Configure the API key and app appearance (`SettingsView`).

### 4\. Data Fetching & Display

ViewModels are responsible for fetching data from the `APIService`. They use `@Published` properties to expose data to the SwiftUI views, which automatically update when the data changes. The `Combine` framework is used extensively for handling asynchronous data streams.

### 5\. User Interactions & Actions

User actions in the views are delegated to their respective ViewModels. The ViewModel processes the action, interacts with the `APIService` or other services, and updates its state, which in turn updates the UI.

-----

## 🧩 Core Components & Their Interactions

### App Entry & Root UI

`OpenAssistantApp` is the entry point, setting up the main window and environment. `ContentView` acts as the root view, displaying `MainTabView` or a loading indicator based on the state managed by `ContentViewModel`.

### API Service Layer

The `APIService` and its extensions form a dedicated layer for all OpenAI API communications. It handles request creation, authentication, response decoding, and error handling. The `FileUploadService` specializes in handling multipart file uploads.

### Base ViewModels

`BaseViewModel` provides common functionalities like `OpenAIService` access and error handling. `BaseAssistantViewModel` extends this for assistant-specific ViewModels.

### Assistant Management

This feature allows users to perform full CRUD operations on assistants. `AssistantManagerView` and its `ViewModel` handle the list of assistants, while `AssistantDetailView` and its `ViewModel` manage the configuration of individual assistants.

### Chat Functionality

`ChatView` and its `ViewModel` provide the core chat experience. They manage the creation of threads, sending and receiving messages, and polling for run status updates. `MessageStore` ensures that chat history is persisted locally.

### Vector Store & File Management

This feature allows users to manage vector stores and their associated files. `VectorStoreListView` and its `ViewModel` handle the list of vector stores, while `VectorStoreDetailView` provides details and file management options.

### Settings

The `SettingsView` allows users to configure the application, including the OpenAI API key and appearance settings.

### Data Persistence

  - **`MessageStore`**: Persists chat history using `UserDefaults` and JSON serialization.
  - **`@AppStorage`**: Used for storing the API key and appearance settings.

### Decoupled Communication

`NotificationCenter` is used to broadcast significant events (e.g., `assistantCreated`, `settingsUpdated`), allowing different parts of the application to stay in sync without being tightly coupled.

-----

## 📊 Visualizing Interactions (`interactions.html`)

The `interactions.html` file provides a visual, interactive diagram of the component interactions within the application, offering a clear overview of the architecture and data flow.

-----

## 🛠️ Potential Refinements & Considerations

  - **Error Handling**: Enhance error handling with more specific error messages and user-friendly recovery options.
  - **Unit Testing**: Increase unit test coverage for ViewModels and services to ensure robustness.
  - **Performance Optimization**: Profile and optimize data fetching and UI rendering for a smoother experience.
  - **Accessibility**: Improve accessibility by adding labels and hints to all UI elements for better VoiceOver support.

-----

## 🚀 Getting Started

### Prerequisites

  - Xcode 15 or later
  - Swift 5.9 or later
  - An OpenAI API key

### Installation & Setup

1.  **Clone the repository:**

    ```sh
    git clone [https://github.com/Gunnarguy/OpenAssistant.git](https://github.com/Gunnarguy/OpenAssistant.git)
    cd OpenAssistant
    ```

2.  **Open the project in Xcode:**

    ```sh
    open OpenAssistant.xcodeproj
    ```

3.  **Set your OpenAI API key:**

      - Run the application.
      - Navigate to the **Settings** tab.
      - Enter your OpenAI API key and tap "Save Settings".

4.  **Build and run** the project on your iOS device or simulator.

---

## 🏗️ Architecture

OpenAssistant follows the **MVVM (Model-View-ViewModel)** pattern with:

- **Models**: OpenAI API entities (`Assistant`, `Message`, `VectorStore`)
- **Views**: SwiftUI components (`ChatView`, `AssistantManagerView`)
- **ViewModels**: Business logic and state management
- **Services**: API communication layer

```
OpenAssistant/
├── Main/                   # App entry point & core utilities
├── APIService/             # OpenAI API integration layer
├── MVVMs/                  # ViewModels and Views by feature
│   ├── Bases/              # Base classes for inheritance
│   ├── Chat/               # Chat interface components
│   ├── Assistants/         # Assistant management
│   └── VectorStores/       # File and vector store management
└── Assets.xcassets/        # App icons and resources
```

**See detailed architecture**: [docs/interactions.html](docs/interactions.html)

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](docs/contributing/CONTRIBUTING.md) for:

- Development setup
- Code style guidelines  
- Pull request process
- Architecture patterns

**Quick start for contributors:**
1. Fork the repository
2. Create a feature branch
3. Follow our MVVM patterns
4. Submit a pull request

---

## 📄 License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

**TL;DR**: Free to use, modify, and distribute. No warranty provided.

```
```
