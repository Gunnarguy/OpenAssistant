# Repository Setup Checklist

## GitHub Repository Settings To Configure

### 1. About Section
Go to your repo → Settings → General, and set:

**Description**: "A native SwiftUI iOS client for the OpenAI Assistants API with comprehensive assistant management, vector stores, and chat functionality"

**Website**: https://github.com/Gunnarguy/OpenAssistant

**Topics** (comma-separated):
```
ios, swift, swiftui, openai, assistant, ai, gpt, chatbot, mobile, mvvm, combine, vector-store, api-client
```

### 2. Features to Enable
In Settings → General:
- ✅ Wikis (for detailed documentation)
- ✅ Issues (for bug reports)
- ✅ Sponsorships (if you want donations)
- ✅ Projects (for roadmap tracking)
- ✅ Discussions (for community questions)

### 3. Branch Protection Rules
Go to Settings → Branches → Add rule:

**Branch name pattern**: `main`

**Protect matching branches**:
- ✅ Require a pull request before merging
- ✅ Require approvals: 1
- ✅ Dismiss stale PR approvals when new commits are pushed
- ✅ Require status checks to pass before merging
- ✅ Require branches to be up to date before merging
- ✅ Include administrators
- ✅ Allow force pushes: ❌
- ✅ Allow deletions: ❌

### 4. Security Settings
In Settings → Security:
- ✅ Enable Dependabot alerts
- ✅ Enable Dependabot security updates
- ✅ Enable Dependency graph

### 5. Pages (Optional)
If you want a website:
- Settings → Pages
- Source: Deploy from a branch
- Branch: main / docs

## Quick Commands to Run

After setting up branch protection, use this workflow:

```bash
# Create feature branch
git checkout -b feature/my-new-feature

# Make changes, commit
git add .
git commit -m "Add new feature"

# Push and create PR
git push -u origin feature/my-new-feature
# Then create PR on GitHub web interface
```

## Repository Quality Badges

Add these to your README.md:

```markdown
![iOS](https://img.shields.io/badge/iOS-15.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)
![GitHub issues](https://img.shields.io/github/issues/Gunnarguy/OpenAssistant)
![GitHub stars](https://img.shields.io/github/stars/Gunnarguy/OpenAssistant)
```
