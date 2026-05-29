## Description

*Provide a brief summary of the changes introduced by this pull request.*
*Detail what problem it solves, what features are added, and how the changes were verified.*

---

## 🛠️ Type of Change

- [ ] 🐛 Bug fix (non-breaking change which fixes an issue)
- [ ] ✨ New feature (non-breaking change which adds functionality)
- [ ] 💥 Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] 📚 Documentation update
- [ ] 🎨 Code style or formatting changes
- [ ] ♻️ Refactoring (no functional changes)

---

## 🧪 Testing and QA Checklist

Please verify that you have tested your modifications using these workflows:
- [ ] **Build Validation**: The project builds successfully (`xcodebuild` or standard `⌘+B` in Xcode) with zero compile errors.
- [ ] **Credential Protection**: Verified that no OpenAI API keys or credentials are committed or printed in console logs.
- [ ] **Asynchronous Polling**: Checked that thread execution timers invalidate correctly on view deinitialization to prevent memory leaks.
- [ ] **File Processing**: If modifying upload features, verified that HEIC, RTF, or text conversions execute off the main thread.
- [ ] **UI Adaptability**: Verified that layouts adapt correctly in Light, Dark, and System appearance modes.

---

## 📋 General PR Checklist

- [ ] My code adheres to the project's coding conventions and MVVM-S patterns.
- [ ] All new ViewModels inherit from `BaseViewModel` or `BaseAssistantViewModel` and are marked `@MainActor`.
- [ ] Inter-ViewModel messaging relies on decoupled `NotificationCenter` broadcasts rather than direct delegation.
- [ ] I have commented my code, particularly in complex asynchronous blocks.
- [ ] I have updated the documentation (`README.md`, `ARCHITECTURE.md`, `docs/CASE_STUDY.md`) if architectural adjustments were introduced.

---

## 🔗 Related Issues & Tickets

Fixes # (issue number)
