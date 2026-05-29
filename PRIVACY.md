# Privacy Policy
> **Last updated: 2026-05-29**
> On-device sandboxing, network transmission transparency, and regulatory disclosures.

---

## 📱 On-Device Data Sandboxing

OpenAssistant is architected with a local-first philosophy. We minimize the retention of credentials and data by sandboxing information strictly inside the local iOS device containers:

1. **User Defaults (`UserDefaults`):**
   - Holds the encrypted-at-rest OpenAI API Key under the key `"OpenAI_API_Key"`.
   - Stores the visual appearance mode configuration under the key `"appearanceMode"`.
2. **Chat Persistence (`MessageStore`):**
   - Conversation histories are JSON-serialized and stored in `UserDefaults` under the key `"savedMessages"`.
   - No external database engines (such as CoreData, SwiftData, or SQLite) are run, avoiding database-corruption issues and reducing storage footprints.
3. **Local Temporary File Directory:**
   - Selected documents (PDF, RTF, images, audio) are copied into the app's sandboxed `tmp/` folder temporarily during the on-device conversion process (`FileProcessor`).
   - Converted files (e.g., `.jpg` or `.txt` formats) are purged immediately from `tmp/` once uploaded to the OpenAI files endpoint.

---

## 📡 Data Sent Off-Device (Transparency Table)

The application contacts only the endpoints necessary to perform AI operations and log application errors. No advertising SDKs are present.

| Destination | Host / Domain | Data Transmitted | Purpose of Transmission | User Control / Opt-Out |
| :--- | :--- | :--- | :--- | :--- |
| **OpenAI API** | `api.openai.com` | OpenAI API Key, chat inputs, assistant details, and uploaded file binaries. | Essential functionality: fetches models, runs assistant threads, queries vector stores, and uploads files. | Users can clear conversations, delete files from vector stores, or remove the API key to immediately disconnect. |
| **Firebase Analytics & Crashlytics** | `firebasestate.google.com` | Anonymized device telemetry (iOS version, device model, session start/end times), crash logs, and stack traces. | Quality assurance: monitors app stability, tracks crashes, and gauges version distribution. | Managed via system-level iOS diagnostic settings (Settings → Privacy & Security → Analytics & Improvements). |

---

## 🚫 SDK & Tracker Exclusions

We explicitly declare the absolute absence of the following third-party components:
- **No Advertising Frameworks:** No Google AdMob, Unity Ads, AppLovin, or comparable ad networks.
- **No Marketing Trackers:** No Facebook SDK, TikTok SDK, Segment, or tracking pixels.
- **No Third-Party Brokers:** No user data is sold, rented, or brokered. 

---

## ⚖️ Regulatory Compliance & Contacts

- **Children's Privacy:** OpenAssistant is built for users aged 13 and above. We do not collect or store personal profiles of children.
- **GDPR / CCPA Readiness:** As a local-first client, we do not host user accounts. For any inquiries regarding support ticket records or diagnostic logs, contact the developer at:
  - **Email:** [privacy@fascinaiting.me](mailto:privacy@fascinaiting.me)
  - **Mailing Address:** OpenAssistant Support, 548 Market St PMB 32110, San Francisco, CA 94104, USA.
