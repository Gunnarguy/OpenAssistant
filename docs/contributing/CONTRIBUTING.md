# Contributing to OpenAssistant

Thank you for your interest in contributing to OpenAssistant! This document provides guidelines for contributing to the project.

## How to Contribute

### Reporting Issues
- Use GitHub Issues to report bugs or request features
- Provide clear reproduction steps for bugs
- Include iOS version, Xcode version, and device information

### Pull Requests
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Follow the existing code style and architecture patterns
4. Add tests if applicable
5. Update documentation if needed
6. Submit a pull request with a clear description

## Development Setup

1. **Prerequisites**
   - Xcode 15+
   - iOS 15.0+ deployment target
   - Valid OpenAI API key for testing

2. **Architecture Guidelines**
   - Follow MVVM pattern
   - Use inheritance hierarchy (BaseViewModel, BaseAssistantViewModel)
   - Service injection via `performServiceAction`
   - NotificationCenter for decoupled communication

3. **Code Style**
   - Use meaningful variable and function names
   - Add comments for complex logic
   - Follow Swift naming conventions
   - Keep functions concise

## Testing
- Test on physical devices when possible
- Verify API integrations work correctly
- Test error handling scenarios
- Ensure UI works across different screen sizes

## Code Review Process
1. All changes require pull request review
2. Maintainers will review for:
   - Code quality and architecture adherence
   - Functionality and testing
   - Documentation updates

## Questions?
Feel free to open an issue for questions about contributing or reach out to the maintainers.

## Code of Conduct
Be respectful and constructive in all interactions. We want this to be a welcoming environment for all contributors.
