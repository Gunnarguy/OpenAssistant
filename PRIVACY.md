# Privacy Policy
> **Last updated: September 23, 2026**
<p align="center">
  <strong>Transparency report detailing data residency, local sandboxing, network transmissions, and SDK exclusions.</strong>
</p>

---

## 📱 1. On-Device Data Sandboxing

OpenAssistant is engineered with a **data sovereignty** model. We minimize external data transmission by caching resources strictly within iOS-managed application boundaries:

- **UserDefaults Configs**:
  - The OpenAI API Key is persisted locally using the key `"OpenAI_API_Key"`.
  - Preferred UI appearance selection is saved under `"appearanceMode"`.
- **Chat Persistence**:
  - Thread history lists are JSON-serialized and stored in `UserDefaults` under the key `"savedMessages"`. No external database engines or remote syncing layers are used.
- **Picked Files**:
  - Selected files (HEIC images, RTF notes, etc.) are read in place through security-scoped access; format conversions and uploads run from memory, so nothing is written to the app's `tmp/` folder.

---

## 📡 2. Data Sent Off-Device (Transparency Catalog)

The application contacts external services only to perform core AI thread execution, fetch custom assistant parameters, and, in builds from the current source, send Firebase Analytics events to Google's Firebase servers. No advertising or commercial marketing trackers are present.

| Destination / SDK | Target Endpoint | Data Transmitted | Purpose of Transmission | User Control / Opt-Out |
|---|---|---|---|---|
| **OpenAI API** | `api.openai.com` | OpenAI API Key, user-entered chat prompts, assistant configurations, and uploaded vector file binaries. | Core functionality: manages assistants, files, threads, and executes runs. | Users can disconnect immediately by deleting their API key from Settings, clearing messages, or deleting files from vector stores. |
| **Firebase Analytics** (added to the source after 3.2) | Google's Firebase servers | Analytics events and basic device information collected by the Firebase Analytics SDK. The App Store build (3.2) does not include Firebase. | Usage measurement for builds made from this source. | No in-app switch. iOS's *Analytics & Improvements* setting does not control it. |

---

## 🚫 3. SDK & Ad-Tracker Exclusions

We explicitly declare the absence of third-party tracking components:
- **No Ad Networks**: No Google AdMob, Unity Ads, AppLovin, or other advertisement frameworks.
- **No Marketing Trackers**: No Facebook SDK, TikTok SDK, Segment, or tracking pixels.
- **No Data Brokers**: No user data is sold, rented, shared, or brokered.

---

## 📝 4. App Store Privacy Disclosures

To assist with App Store review submissions, the app's privacy label requires the following disclosures:
- **Data Linked to You**: None. The app does not host user accounts.
- **Diagnostics**: No crash logs are collected. The only third-party SDK is Firebase Analytics, which in builds from the current source sends analytics events to Google's Firebase servers; the App Store build (3.2) did not include it.
- **User Content**: Chat inputs and file uploads are processed directly by OpenAI. They are not sent to developer servers.

---

## ⚖️ 5. Regulatory Contacts

- **GDPR / CCPA Compliance**: Because the application uses direct client-to-API communication, the developer does not host user profiles. To request the removal of support tickets or feedback communications, contact the support team:
  - **Email**: [privacy@fascinaiting.me](mailto:privacy@fascinaiting.me)
  - **Mailing Address**: OpenAssistant Support, 548 Market St PMB 32110, San Francisco, CA 94104, USA.
