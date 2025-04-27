<div align="center">
<h1 align="center">
<img src="https://raw.githubusercontent.com/PKief/vscode-material-icon-theme/ec559a9f6bfd399b82bb44393651661b08aaf7ba/icons/folder-markdown-open.svg" width="100" />
<br>
OpenAssistant
</h1>
<h3 align="center">📍 A native SwiftUI iOS client for interacting with the OpenAI Assistants API</h3>
<h3 align="center">⚙️ Developed with the software and tools below:</h3>

<p align="center">
<img src="https://img.shields.io/badge/Swift-F05138.svg?style=for-the-badge&logo=Swift&logoColor=white" alt="Swift" />
<img src="https://img.shields.io/badge/JSON-000000.svg?style=for-the-badge&logo=JSON&logoColor=white" alt="JSON" />
</p>
</div>

---

## 📚 Table of Contents
- [📚 Table of Contents](#-table-of-contents)
- [📍 Overview](#-overview)
- [✨ Key Features](#-key-features)
- [📂 Project Structure](#-project-structure)
- [🌊 Application Flow](#-application-flow)
- [🧩 Modules](#modules)
- [🚀 Getting Started](#-getting-started)
- [🗺 Roadmap](#-roadmap)
- [🤝 Contributing](#-contributing)
- [📄 License](#-license)
- [👏 Acknowledgments](#-acknowledgments)

---


## 📍 Overview

OpenAssistant is a native iOS application built entirely with SwiftUI, designed to provide a seamless and intuitive interface for interacting with the OpenAI Assistants API. It allows users to create, manage, and chat with custom AI assistants directly from their iPhone or iPad. The app handles the complexities of the Assistants API, including thread management, vector stores, file uploads, and tool usage (like Code Interpreter and File Search), offering a robust platform for leveraging OpenAI's powerful assistant capabilities in a user-friendly mobile environment.

---

## ✨ Key Features

<!-- Placeholder for App Screenshots -->
**Screenshots:**

*(Consider adding screenshots here showcasing the main features like the Chat Interface, Assistant Management, and Vector Store Management)*

| Feature                     | Description                                                                                                                               |
| :-------------------------- | :---------------------------------------------------------------------------------------------------------------------------------------- |
| **🤖 Assistant Management**   | Create, view, update, and delete OpenAI Assistants. Configure name, instructions, model, description, temperature, and top P settings.     |
| **🛠️ Tool Enablement**       | Enable or disable tools for assistants, including Code Interpreter and File Search (Retrieval).                                             |
| **🗂️ Vector Store Management** | Create, view, update, and delete Vector Stores. Associate Vector Stores with Assistants to enable file-based knowledge retrieval.         |
| **📄 File Management**        | Upload files to OpenAI and associate them with specific Vector Stores. View file details and manage files within stores.                  |
| **💬 Chat Interface**        | Engage in conversations with selected Assistants. Handles message history, thread management, and displays assistant responses.             |
| **🔄 Real-time Updates**     | Utilizes Combine and NotificationCenter for reactive updates across the UI when assistants, stores, or settings change.                   |
| **🔑 Secure API Key Handling**| Securely stores and manages the OpenAI API key using `AppStorage`.                                                                        |
| **📱 Native iOS Experience**  | Built with SwiftUI for a modern, responsive, and platform-native user experience, including support for Dark Mode.                      |
| **🏗️ MVVM Architecture**     | Organizes code using the Model-View-ViewModel (MVVM) pattern for better separation of concerns, testability, and maintainability.        |
| **⚙️ API Service Layer**      | Dedicated service layer (`APIService`) encapsulates all interactions with the OpenAI API, handling requests, responses, and errors.       |

---

<img src="https://raw.githubusercontent.com/PKief/vscode-material-icon-theme/ec559a9f6bfd399b82bb44393651661b08aaf7ba/icons/folder-github-open.svg" width="80" />

## 📂 Project Structure

The project follows the Model-View-ViewModel (MVVM) architectural pattern, promoting separation of concerns, testability, and maintainability. Here's a breakdown of the key components and their relationships:

```mermaid
graph TD
    subgraph User Interface (SwiftUI Views)
        direction LR
        CV(ContentView)
        MTV(MainTabView)
        ChatV(ChatView)
        AsstMgrV(AssistantManagerView)
        AsstDetailV(AssistantDetailView)
        VecStoreListV(VectorStoreListView)
        SettingsV(SettingsView)
    end

    subgraph ViewModels (State & Logic)
        direction LR
        ContentVM(ContentViewModel)
        ChatVM(ChatViewModel)
        AsstMgrVM(AssistantManagerViewModel)
        AsstDetailVM(AssistantDetailViewModel)
        VecStoreMgrVM(VectorStoreManagerViewModel)
        BaseVM(BaseViewModel)
    end

    subgraph Services
        APIService(APIService)
    end

    subgraph External
        OpenAI(OpenAI API)
    end

    UserInterface --> ViewModels
    ViewModels --> Services
    Services --> External

    CV --- ContentVM
    MTV --- ChatV & AsstMgrV & VecStoreListV & SettingsV
    ChatV --- ChatVM
    AsstMgrV --- AsstMgrVM
    AsstDetailV --- AsstDetailVM
    VecStoreListV --- VecStoreMgrVM

    ContentVM -.-> BaseVM
    ChatVM -.-> BaseVM
    AsstMgrVM -.-> BaseVM
    AsstDetailVM -.-> BaseVM
    VecStoreMgrVM -.-> BaseVM

    BaseVM --> APIService
    ChatVM --> APIService
    AsstMgrVM --> APIService
    AsstDetailVM --> APIService
    VecStoreMgrVM --> APIService

    APIService --> OpenAI

    style UserInterface fill:#f9f,stroke:#333,stroke-width:2px
    style ViewModels fill:#ccf,stroke:#333,stroke-width:2px
    style Services fill:#cfc,stroke:#333,stroke-width:2px
    style External fill:#fcc,stroke:#333,stroke-width:2px
```

-   **`OpenAssistant/`**: The main application module containing all source code, resources, and configuration.

    -   **`APIService/`**: This directory is the dedicated layer for all network interactions with the OpenAI API. It abstracts the complexities of API calls, authentication, request building, response parsing, and error handling.
        -   `OpenAIService.swift`: The core class defining common request logic, headers, and response handling (`handleResponse`, `handleDeleteResponse`, `handleHTTPError`). It acts as the base for specific API interactions.
        -   `OpenAIInitializer.swift`: Provides a static method to initialize and configure the shared `OpenAIService` instance, ensuring consistent setup with the API key.
        -   `OpenAIService-*.swift` (e.g., `-Assistant`, `-Threads`, `-Vector`): Extensions of `OpenAIService` containing methods specific to different OpenAI API endpoints (Assistants, Threads, Messages, Vector Stores, Files). This keeps the API logic organized by feature.
        -   `OpenAIServiceError.swift`: Defines custom error types specific to API interactions (e.g., `rateLimitExceeded`, `invalidResponse`, `decodingError`), providing more context than standard network errors.
        -   `CommonMethods.swift`, `Utils.swift`: Contain shared helper functions and utilities used within the API service layer.

    -   **`Main/`**: Holds core application setup files, global definitions, shared models, and utilities that are not specific to a single feature.
        -   `OpenAssistantApp.swift`: The main entry point (`@main`) of the application. It initializes the root view (`ContentView`), sets up environment objects (like `AssistantManagerViewModel`, `VectorStoreViewModel`), and handles initial checks (like API key presence).
        -   `Additional.swift`, `ResponseFormat.swift`: Define shared data structures (Models) used across different parts of the application, often mirroring parts of the OpenAI API responses but potentially adapted for UI use.
        -   `Extensions.swift`: Contains extensions to standard Swift types (like `String`, `Date`) providing convenient helper methods used throughout the app.
        -   `Errors.swift`: Defines global application-level errors (distinct from API-specific errors).
        -   `FeatureFlags.swift`: Allows toggling features on or off, useful for development and testing.
        -   `ModelCapabilities.swift`: Defines information about different OpenAI models, potentially their capabilities or limitations.

    -   **`MVVMs/`**: This is the heart of the application's features, organized by domain according to the MVVM pattern. Each sub-directory typically contains the Views (UI), ViewModels (state and logic), and sometimes feature-specific Models.
        -   **`Bases/`**: Contains base classes for ViewModels (`BaseViewModel`, `BaseAssistantViewModel`). These provide common functionality like API service access (`openAIService`), error handling (`errorMessage`), API key management (`@AppStorage`), and notification observation, reducing boilerplate in specific ViewModels.
        -   **`Content/`**: Manages the root view hierarchy.
            -   `ContentView.swift`: The main container view presented by `OpenAssistantApp`. It sets up the `MainTabView` and handles the display of loading indicators or initial setup screens (like the API key prompt).
            -   `ContentViewModel.swift`: The ViewModel for `ContentView`. It orchestrates the initial state, manages loading indicators, and potentially handles global state changes affecting the main view.
        -   **`MainTabView.swift`**: Defines the primary tab-based navigation structure of the app (Chat, Assistants, Vector Stores, Settings). It hosts the views for each tab.
        -   **`Assistants/`**: Feature module dedicated to managing OpenAI Assistants.
            -   `AssistantManager/`: Contains `AssistantManagerView` (lists assistants) and `AssistantManagerViewModel` (fetches, creates, updates, deletes assistants; manages the `assistants` array).
            -   `AssistantCreate/`: Views (`CreateAssistantView`, `AssistantFormView`, `ActionButtonsView`) responsible for the multi-step process of creating a new assistant. Logic is likely handled by `AssistantManagerViewModel` or a dedicated creation ViewModel.
            -   `AssistantDetails/`: `AssistantDetailView` displays the configuration of a single assistant. `AssistantDetailViewModel` manages the state for this view, potentially handling updates and interactions like associating Vector Stores.
            -   `AssistantPicker/`: `AssistantPickerView` allows the user to select an assistant to start a chat session. It likely interacts with `AssistantManagerViewModel` to get the list of assistants.
        -   **`Chat/`**: Feature module for the conversational interface.
            -   `ChatView.swift`: The main view for a chat session with a selected Assistant. It orchestrates the `MessageListView` and `InputView`.
            -   `ChatViewModel.swift`: The critical ViewModel managing the entire state of a single chat session. It holds the `messages` array, handles `inputText`, creates/manages the OpenAI Thread, sends messages (`sendMessage`), runs the Assistant (`runAssistantOnThread`), polls for run status (`pollRunStatus`), fetches new messages, and handles loading states and errors for the chat interface.
            -   `MessageListView.swift`, `MessageView.swift`: Views responsible for rendering the list of messages in the conversation.
            -   `InputView.swift`: The UI component containing the text field for user input and the send button.
        -   **`VectorStores/`**: Feature module for managing Vector Stores and associated files.
            -   `VectorStoreListView.swift`: Displays the list of available Vector Stores.
            -   `VectorStoreManagerViewModel.swift`: Manages the fetching, creation, deletion, and updating of Vector Stores. It holds the `vectorStores` array and interacts with the `APIService` for vector store and file operations.
            -   `VectorStoreDetailView.swift`: Shows the details of a specific Vector Store, including its associated files. Allows users to add/remove files.
            -   `Files/`: Contains views like `AddFileView` (for uploading files) and `FileDetailView` (showing details of a file within a store), likely interacting with `VectorStoreManagerViewModel`.
        -   **`Responses/`**: Contains `ResponseView` and `ResponseViewModel`. This seems dedicated to displaying raw or processed responses from a specific API endpoint (perhaps `/v1/responses`), potentially for debugging or a specialized feature.
        -   **`LoadingView.swift`**: A reusable SwiftUI view component displayed when background tasks are in progress.
        -   **`MessageStore.swift`**: Appears to be responsible for persisting chat messages locally, though its current implementation might be basic.

    -   **`Assets.xcassets/`**: Stores application assets like icons, images, and color sets.
    -   **`Preview Content/`**: Contains assets used specifically for generating SwiftUI Previews in Xcode.
    -   **`cline_docs/`**: Developer-specific documentation, like roadmaps or task lists.
    -   **`Info.plist`**, **`PrivacyInfo.xcprivacy`**: Standard iOS application configuration files defining metadata, permissions, and privacy practices.
    -   **`.xcconfig` files**: Xcode build configuration files (Debug, Release) allowing different settings for various build types.

-   **`OpenAssistant.xcodeproj/`**: The Xcode project file. It defines targets, build settings, dependencies, and the overall structure recognized by Xcode.

---

## 🌊 Application Flow

Here's a high-level overview of the typical user flow and application logic:

```mermaid
flowchart TD
    A[App Launch] --> B{API Key Set?};
    B -- No --> C[Show SettingsView];
    C --> D[User Enters Key];
    D --> E[Save Key];
    B -- Yes --> F[Show MainTabView];
    E --> F;

    F --> G{Select Tab};
    G -- Chat --> H[AssistantPickerView];
    G -- Assistants --> I[AssistantManagerView];
    G -- Vector Stores --> J[VectorStoreListView];
    G -- Settings --> C;

    H --> K{Select Assistant};
    K --> L[Navigate to ChatView];
    L --> M[ChatViewModel Manages Thread/Messages];
    M --> N[User Sends Message];
    N --> O[ChatVM calls APIService];
    O --> P[APIService interacts with OpenAI];
    P --> Q[APIService returns response];
    Q --> R[ChatVM updates Messages];
    R --> S[MessageListView Updates];
    S --> N; // Loop back for more messages

    I --> T{User Action};
    T -- Create --> U[Show CreateAssistantView];
    T -- View/Edit --> V[Show AssistantDetailView];
    T -- Delete --> W[Call APIService to Delete];

    J --> X{User Action};
    X -- Create --> Y[Show Create Vector Store UI];
    X -- View/Edit --> Z[Show VectorStoreDetailView];
    Z --> AA[Manage Files (Add/Remove)];

    style A fill:#lightgrey,stroke:#333
    style F fill:#lightblue,stroke:#333
    style L fill:#lightgreen,stroke:#333
    style I fill:#lightyellow,stroke:#333
    style J fill:#lightcoral,stroke:#333
```

1.  **App Launch**: The `OpenAssistantApp` initializes the main view (`ContentView`).
2.  **API Key Check**: On appearance, the `ContentViewModel` checks if an OpenAI API key is stored using `@AppStorage`. If not, the `SettingsView` is presented modally.
3.  **Settings**: The user enters their API key in the `SettingsView`, which is saved securely.
4.  **Main Interface (`MainTabView`)**: The user is presented with a tabbed interface:
    *   **Chat Tab**: Shows the `AssistantPickerView` to select an existing assistant to chat with.
    *   **Assistants Tab**: Displays the `AssistantManagerView` to manage (create, view, update, delete) assistants.
    *   **Vector Stores Tab**: Presents the `VectorStoreListView` to manage vector stores and their associated files.
5.  **Assistant Interaction**:
    *   Users can create a new assistant via `CreateAssistantView`.
    *   Existing assistants can be viewed/edited in `AssistantDetailView`. This includes associating Vector Stores.
6.  **Vector Store Interaction**:
    *   Users can create new vector stores.
    *   Files can be uploaded and associated with stores via `AddFileView` within the `VectorStoreDetailView`.
7.  **Chatting**:
    *   Selecting an assistant from the `AssistantPickerView` navigates to the `ChatView`.
    *   The `ChatViewModel` manages creating a new thread (if needed) and handles sending messages to/receiving messages from the selected assistant via the `APIService`.
    *   Messages are displayed in `MessageListView`, and input is handled by `InputView`.

---

## 👏 Acknowledgments

> - [📌  List any resources, contributors, inspiration, etc.]

---
