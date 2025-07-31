# OpenAssistant iOS Client Development Guide

## Architecture & Core Patterns

### MVVM with Inheritance Hierarchy

- **Base Classes**: All ViewModels inherit from `BaseViewModel` or `BaseAssistantViewModel` in `MVVMs/Bases/`
- **Service Injection**: Use `performServiceAction { openAIService in ... }` pattern for API calls
- **Error Handling**: Use `handleResult()` method and `IdentifiableError` for consistent error presentation
- **API Initialization**: Service auto-reinitializes via `OpenAIServiceInitializer.initialize()` when API key changes

### Decoupled Communication via NotificationCenter

Critical notification patterns defined in `Main/Extensions.swift`:

```swift
.assistantCreated, .assistantUpdated, .assistantDeleted
.vectorStoreCreated, .vectorStoreUpdated, .vectorStoreDeleted
.settingsUpdated, .didUpdateAssistant
```

- ViewModels subscribe to relevant notifications in `setupNotificationObservers()`
- Post notifications after successful API operations for real-time UI sync
- Use `.receive(on: DispatchQueue.main)` for UI updates

### Message Persistence & Threading

- **MessageStore**: Central chat history manager using `@AppStorage` with JSON serialization
- **Thread Management**: Each chat creates OpenAI threads; messages filtered by `thread_id`
- **Deduplication**: Store handles message deduplication by ID automatically
- **Loading Strategy**: Call `messageStore.addMessages()` for assistant responses, `messageStore.addMessage()` for user messages

### API Service Architecture

- **Main Service**: `OpenAIService` with method extensions in separate files (`OpenAIService-Assistant.swift`, etc.)
- **Retry Logic**: Built-in exponential backoff in `performDataTaskWithRetry()`
- **Request Pattern**: Use `makeRequest()` with proper headers (`assistants=v2` beta header required)
- **Error Types**: Custom `OpenAIServiceError` enum for typed error handling

## Development Workflows

### Building & Running

- **iOS Target**: Minimum deployment iOS 15.0 (defined in `Package.swift`)
- **Swift Package**: Use `swift build` for package validation
- **Xcode**: Open `OpenAssistant.xcodeproj` for full iOS development

### File Organization Conventions

- **Feature-based**: Each MVVM feature in `MVVMs/{FeatureName}/` with View+ViewModel pairs
- **Shared Views**: Feature-specific sub-components in `{Feature}Parts/` directories
- **API Extensions**: Separate service functionality by domain (Assistant, Threads, Vector)

### State Management Patterns

- **Loading States**: Use enum-based loading states (see `ChatViewModel.LoadingState`)
- **Published Properties**: All UI state as `@Published` in ViewModels
- **Background Tasks**: Mark long-running API operations with `isBackground: true` in UI

## Project-Specific Conventions

### Vector Store & File Management

- **Dual API Pattern**: Both Combine publishers and completion handler APIs available
- **File Caching**: `VectorStoreManagerViewModel` maintains local file cache for performance
- **Chunking Strategy**: Always specify `ChunkingStrategy` for file uploads
- **Optimistic Updates**: Update local caches immediately, then refresh from API

### Assistant Configuration

- **Tool Resources**: Assistant tools managed via `tool_resources.fileSearch.vectorStoreIds` array
- **Model Capabilities**: Check O-series model support for `reasoning_effort` parameter
- **Dynamic Updates**: Use completion handlers in update operations for proper sequencing

### Environment & Configuration

- **API Key Storage**: Secured via `@AppStorage("OpenAI_API_Key")`
- **Appearance**: System-level theme support through `AppearanceMode` enum
- **Service Initialization**: Lazy initialization pattern with thread-safe singleton

### Testing & Debugging

- **Logging Pattern**: Extensive `print()` statements for operation tracing (remove in production)
- **Preview Support**: All views include `#Preview` with mock data
- **Error Recovery**: Graceful degradation with user-friendly error messages

## Integration Points

### OpenAI API Specifics

- **Beta Headers**: Always include `OpenAI-Beta: assistants=v2` header
- **Polling Pattern**: Use timer-based polling for run status updates (2-second intervals)
- **File Types**: Support PDF, TXT, DOCX with proper MIME type handling
- **Rate Limiting**: Built-in retry logic handles transient failures

### Platform Integration

- **SwiftUI Lifecycle**: Proper `@MainActor` usage for all ViewModels
- **Combine Framework**: Extensive use for reactive data flow and async operations
- **URLSession**: Custom session configuration for API requests with timeout handling

Focus on maintaining the established patterns when adding features. The architecture prioritizes type safety, reactive updates, and clear separation of concerns across the MVVM layers.
