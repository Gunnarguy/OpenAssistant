# Security Policy & Secrets Management
<p align="center">
  <strong>Guidelines outlining secret isolation, network boundary controls, local storage rules, and developer safeguards.</strong>
</p>

---

## 🔒 1. Secrets Management & Storage Model

OpenAssistant is a **Bring-Your-Own-Key (BYOK)** native application. It requires a personal OpenAI API Key to perform network calls. Keeping this key secure is the application's top priority.

### Key Storage Model
- **Current State**: The API Key is persisted locally using SwiftUI's `@AppStorage("OpenAI_API_Key")` wrapper, which interfaces with `UserDefaults`.
  - On iOS, the `UserDefaults` plist file is sandboxed within the application container. The operating system encrypts this data at rest when the device is locked (using default iOS file protection policies).
- **Identified Risk**: On jailbroken iOS devices with root accessibility, sandboxed plist configuration files can be inspected using root file browsers.
- **Migration Target**: We plan to migrate the API key storage to Apple's **Keychain Services API** (leveraging the Secure Enclave) to require biometric verification (Face ID / Touch ID) before retrieving the key.

### Session Logs
Conversation history is saved as a JSON string inside `UserDefaults` under the key `savedMessages` in [MessageStore.swift](OpenAssistant/MVVMs/Chat/ChatParts/MessageStore.swift). No remote database engines are used.

---

## 📡 2. Network Boundary Controls

To guarantee data sovereignty and privacy, OpenAssistant strictly restricts network communication:
1. **Direct TLS 1.3 Communication**: The application talks directly to OpenAI's server (`api.openai.com`). No intermediate proxy servers or developer-owned servers are used.
2. **ATS Rules Enforced**: App Transport Security (ATS) rules configured in `Info.plist` block cleartext HTTP traffic. Only secure HTTPS communication is permitted.
3. **Telemetry Restrictions**: Anonymized crash logs and device metrics are sent to Google Firebase (`firebasestate.google.com`). Firebase configuration parameters contain no custom developer keys or user identification data.

---

## 🛡️ 3. Release-Build Safeguards & Commit Guards

To prevent accidental distribution of developer-owned API keys:

### 1. Git Pre-Commit Secret Scanner
During developer setup (`setup.sh`), a pre-commit hook is installed at `.git/hooks/pre-commit`. The hook automatically scans files staged for commits for OpenAI API key patterns (`sk-[a-zA-Z0-9]{32,}`) and aborts the commit if a match is found:

```bash
# Checks if API key patterns are staged for git commits
KEY_PATTERN="sk-[a-zA-Z0-9]{32,}"
if grep -qE "$KEY_PATTERN" "$FILE"; then
    echo "❌ ERROR: Potential hardcoded OpenAI API Key detected in: $FILE"
    exit 1
fi
```

### 2. Signing Profiles (.xcconfig)
Build configuration variables (such as Apple Developer Team IDs and Bundle Identifiers) are stored in local `.xcconfig` templates (`Debug.xcconfig` and `Release.xcconfig`) instead of the project file. Placeholder values are tracked, forcing developers to configure signing credentials locally.

---

## 🧼 4. Security Checklist for Future Changes

When modifying the codebase, developers must adhere to the following:
- **No API Key Storage in Code**: Never commit mock API keys, raw strings, or test tokens. Use on-device input forms only.
- **Background Purge of Files**: Ensure any temporary files stored in the sandbox `tmp/` folder during file processing are deleted immediately after transmission.
- **No Console Key Leakage**: Never print raw API keys, thread authorization tokens, or decrypted user payloads in console logging commands.
- **Dependencies Verification**: Run `pod update` regularly to scan CocoaPods dependencies (Firebase Core/Analytics) for vulnerabilities.

---

## 📣 5. Vulnerability Reporting Process

If you discover a potential security vulnerability in this repository, please do not file a public issue. Email the developer directly:
- **Email**: [security@fascinaiting.me](mailto:security@fascinaiting.me)
- **Mailing Address**: OpenAssistant Security Team, 548 Market St PMB 32110, San Francisco, CA 94104, USA.
