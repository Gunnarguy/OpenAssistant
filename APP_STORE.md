# App Store Connect Listing Copy & Review Guidelines
> **Last updated: 2026-05-29**
> Metadata assets, reviewer notes, and manual testing procedures.

---

## 📝 App Store Listing Copy

### 1. Promotional Text
> Bring the full power of OpenAI’s Assistants API directly to your pocket. Connect custom AI agents, attach vector stores, and upload documents locally.

### 2. Description
OpenAssistant is a native SwiftUI client designed for developers, researchers, and power users who want complete mobile control over the OpenAI Assistants API (v2). 

Enter your personal OpenAI API key and start orchestrating your custom AI assistants, thread histories, and knowledge vector stores in a beautifully designed, responsive iOS dashboard.

**Key Features:**
* **Assistant Lifecycle CRUD:** Create, view, edit, and delete assistants. Fully configure names, instructions, models (including GPT-4o and o-series reasoning models), temperature, Top-P, and reasoning effort.
* **Knowledge Retrieval via Vector Stores:** Create, inspect, and manage Vector Stores on OpenAI. Link stores to assistants to enable semantic document retrieval.
* **On-Device File Processing:** Upload files (PDFs, TXT, DOCX) directly. Features local, on-device conversion of unsupported types (HEIC to JPEG, RTF to TXT, and audio files to plain text placeholders) before transmission to save bandwidth.
* **Interactive Markdown Chat:** Chat with your assistants in a conversational interface featuring Markdown formatting, persistent local history cache (`MessageStore`), and automatic thread execution run polling.
* **Privacy-First Architecture:** Direct TLS communication with OpenAI. Your API key and chats reside locally inside your device’s sandbox (`UserDefaults`). No third-party servers, tracking pixels, or advertising SDKs.

### 3. Keywords
`openai,assistant,ai,agent,vector,rag,chatgpt,gpt4o,o1,developer,playground,swiftui,ios`

### 4. Support & Privacy Links
- **Support URL:** [https://gunzino.me/openassistant/support/](https://gunzino.me/openassistant/support/)
- **Privacy Policy URL:** [https://gunzino.me/openassistant/privacy/](https://gunzino.me/openassistant/privacy/)

---

## 🔑 App Reviewer Credentials & Notes

### API Authentication Setup
OpenAssistant is a **Bring-Your-Own-Key (BYOK)** client. The application requires a valid OpenAI API key with active billing permissions to perform network operations. 

> [!IMPORTANT]
> **For the App Review Team:**
> - To review the app's functionality, please input a valid OpenAI API key in the **Settings** view when prompted on first launch.
> - We recommend using a key restricted to low usage limits for safety. No credentials are transmitted to any servers other than OpenAI (`api.openai.com`).

---

## 📋 Step-by-Step Manual Testing Walkthrough

Follow these instructions to verify the core capabilities of the app:

### 1. Initial Launch & Settings Setup
1. Open the application. Because the API Key is empty on first launch, the **Settings** screen will automatically slide up.
2. Enter your OpenAI API Key in the secure field.
3. Tap **Save Settings**. An alert will display "Settings saved successfully." Tap **OK**. The settings sheet will dismiss, showing the main tab bar dashboard.

### 2. Assistant Lifecycle Management
1. Tap the **Manage** tab (third tab) to view your Assistants list.
2. Tap the `+` button in the top-right corner to open the **Create Assistant** screen.
3. Configure the assistant:
   - **Name:** Enter "Reviewer Bot".
   - **Model:** Select `gpt-4o` from the dropdown list.
   - **Instructions:** Enter "You are a helpful QA assistant."
   - **Tools:** Toggle **Code Interpreter** to enabled.
4. Tap **Create**. The sheet will dismiss, and "Reviewer Bot" will appear in the list.

### 3. Vector Store Creation & File Ingest
1. Tap the **Vector Stores** tab (fourth tab) to list vector stores.
2. Tap the `+` button in the top-right, enter "QA Knowledge Base" as the store name, and tap **Create**.
3. Select "QA Knowledge Base" from the list to view its details.
4. Tap **Add File** (or similar file-picker action).
5. Choose a local text document (`.txt`) or PDF.
6. Configure the chunking parameters (e.g., Max size 800 tokens, Overlap 100 tokens).
7. Tap **Upload & Index**. The file status will cycle through `in_progress` and complete as `completed`.
8. Go back to the **Manage** tab, tap "Reviewer Bot", select **Edit**, and under **Tool Resources** associate the "QA Knowledge Base" vector store. Enable **File Search** tool. Tap **Save**.

### 4. Interactive Chat Session
1. Navigate to the **Assistants** tab (first tab) which displays the Assistant Picker list.
2. Tap "Reviewer Bot". The **ChatView** opens.
3. Type the message: `"Hello! What tools do you have access to?"` and tap the send icon.
4. Verify the loading bar progression states:
   - *Creating Thread*
   - *Running Assistant*
   - *Processing*
   - *Completing*
5. The assistant's reply (mentioning its access to Code Interpreter and File Search) will render in the message list with markdown bubbles.
6. Tap the back button. Re-select "Reviewer Bot" to verify that your message history is preserved locally.

### 5. UI Customization
1. Navigate to the **Settings** tab.
2. Tap **Theme** and toggle between **Light**, **Dark**, and **System** modes. Verify that the UI elements instantly adapt color schemes.
