# OpenAssistant Documentation

Welcome to the OpenAssistant documentation! This directory contains comprehensive guides for users, contributors, and developers.

## 📖 **For Users**

### Getting Started
- **[Installation Guide](installation/INSTALLATION.md)** - How to build and run the app
- **[Distribution Options](installation/DISTRIBUTION.md)** - App Store, TestFlight, and sideloading
- **[Privacy Policy](PRIVACY.md)** - How your data is handled

## 🛠️ **For Contributors**

### Development
- **[Contributing Guidelines](contributing/CONTRIBUTING.md)** - How to contribute to the project
- **[Development Setup](development/REPOSITORY_SETUP.md)** - Setting up your development environment
- **[Project Templates](development/project-template-files.md)** - Reusable templates for other projects

### Architecture & Code
- **[Component Interactions](interactions.html)** - Visual architecture diagram
- **[Copilot Instructions](../.github/copilot-instructions.md)** - AI coding guidelines and patterns

## 🔧 **For Maintainers**

### Operations
- **[Security Scanning](development/SECURITY_SCANNING.md)** - CodeQL setup and security practices
- **[Repository Cleanup](development/CLEANUP_SUMMARY.md)** - What was cleaned up and why

## 🏗️ **Project Structure**

```
OpenAssistant/
├── README.md                    # Main project overview
├── LICENSE                      # MIT License
├── Package.swift               # Swift Package Manager config
├── OpenAssistant.xcodeproj/    # Xcode project
├── OpenAssistant/              # Source code
│   ├── Main/                   # App entry point & core
│   ├── APIService/             # OpenAI API integration
│   ├── MVVMs/                  # ViewModels and Views
│   └── Assets.xcassets/        # App icons & resources
├── docs/                       # 📖 All documentation (this folder)
│   ├── contributing/           # Contributor guides
│   ├── installation/           # User setup guides
│   ├── development/            # Developer resources
│   └── interactions.html       # Architecture visualization
└── .github/                    # GitHub-specific configs
    ├── workflows/              # CI/CD automation
    ├── ISSUE_TEMPLATE/         # Bug & feature templates
    └── pull_request_template.md # PR template
```

## 🚀 **Quick Links**

- [Main README](../README.md) - Project overview
- [GitHub Repository](https://github.com/Gunnarguy/OpenAssistant)
- [OpenAI API Documentation](https://platform.openai.com/docs)

---

**Need help?** Open an issue on [GitHub](https://github.com/Gunnarguy/OpenAssistant/issues)!
