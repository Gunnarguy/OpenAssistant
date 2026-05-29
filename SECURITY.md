# Security Guidelines & Secrets Management
> **Last updated: 2026-05-29**
> Security policies, secrets isolation, compile constraints, and scanning rules.

---

## 🔒 Secrets Management & Storage Architecture

OpenAssistant handles the user's personal OpenAI API Key. It does not utilize intermediate servers or proxies. 

### 1. On-Device Storage Sandbox
- **Current State:** The API Key is persisted locally using SwiftUI's `@AppStorage("OpenAI_API_Key")` wrapper, which interfaces with `UserDefaults`. 
  - On iOS, `UserDefaults` plist files are stored within the application's container sandbox and are encrypted at rest by the operating system when the device is locked (using default iOS file protection).
- **Security Limitation:** On jailbroken devices, sandbox files can be accessed via root explorer utilities.
- **Future Migration Target:** We plan to migrate the API key storage to Apple's **Keychain Services API** (using the Secure Enclave) to require biometric verification (Face ID / Touch ID) before retrieving the key.

### 2. Networking Hygiene
- All connections to `api.openai.com` and `firebasestate` endpoints use **TLS 1.3** (or TLS 1.2 fallback).
- Cleartext HTTP transmission is blocked by iOS App Transport Security (ATS) rules in `Info.plist`.

---

## 🛡️ Archiving & Build Guards

To prevent accidental distribution of builds containing developer-owned credentials:

### 1. Git Pre-Commit Secret Scanner
During the developer onboarding setup (`setup.sh`), a local pre-commit hook is installed at `.git/hooks/pre-commit`. This script automatically scans changed files for raw OpenAI API key patterns (`sk-[a-zA-Z0-9]{32,}`) and aborts the commit if a potential leak is found:

```bash
# Detected raw keys block commits automatically
KEY_PATTERN="sk-[a-zA-Z0-9]{32,}"
if grep -qE "$KEY_PATTERN" "$FILE"; then
    echo "❌ ERROR: Potential hardcoded OpenAI API Key detected in: $FILE"
    exit 1
fi
```

### 2. Configuration Profiles (`.xcconfig`)
Signing identities and build optimization profiles are stored in `Debug.xcconfig` and `Release.xcconfig` instead of the project file:
- `DEVELOPMENT_TEAM = YOUR_TEAM_ID`
- `PROVISIONING_PROFILE_SPECIFIER = YOUR_PROVISIONING_PROFILE`

This ensures team credentials remain local and placeholders are checked in, requiring developers to configure their signing locally in Xcode.

---

## 🧼 Security Hygiene & CI/CD Pipelines

Automated checks are run on every pull request to `main`:

1. **CodeQL Analysis (`codeql.yml`):**
   Scans the Swift codebase for concurrency race conditions, injection vulnerabilities, and memory leak patterns.
2. **Xcode Build Validation:**
   The CI environment compiles the project on a macOS runner with `CODE_SIGNING_ALLOWED=NO` to ensure clean compilation without signing key pollution.
3. **No Hardcoded Keys Audits:**
   If you need to report security vulnerabilities, do not file public GitHub issues. Email the developer directly at `privacy@fascinaiting.me`.
