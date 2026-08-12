# Contributing to Key Recorder

Thank you for your interest in contributing to Key Recorder! This document provides guidelines for contributing to the project.

## Code of Conduct

- Be respectful and constructive in all interactions
- Focus on what is best for the community and the project
- Welcome newcomers and help them get started

## How Can I Contribute?

### Reporting Bugs

Before creating a bug report, please check if the issue has already been reported. When creating a bug report, include:

- **macOS version** (e.g., 14.2.1)
- **Key Recorder version**
- **Steps to reproduce** the issue
- **Expected behavior** vs **actual behavior**
- **Screenshots** if applicable
- **System logs** or crash reports if available

### Suggesting Features

Feature suggestions are welcome! Please provide:

- Clear description of the feature
- Use case and motivation
- Potential implementation approach if you have ideas

### Pull Requests

1. **Fork the repository** and create your branch from `main`
2. **Make your changes** following our coding standards
3. **Test your changes** thoroughly
4. **Update documentation** if necessary
5. **Ensure your code compiles** without warnings
6. **Submit a pull request** with a clear description

## Development Setup

### Prerequisites

- macOS 15.1+
- Xcode 15.0+
- Swift 5.9+

### Building

```bash
git clone https://github.com/romainfrezier/key-recorder.git
cd key-recorder
open key-recorder.xcodeproj
```

Build and run with **⌘+R**

Run tests with **⌘+U**

## Coding Standards

### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use 4 spaces for indentation
- Keep functions small and focused
- Add documentation comments for public APIs
- Prefer `let` over `var`, avoid force unwrapping

### SwiftUI

- Use view modifiers instead of nested structures when possible
- Extract reusable views into separate structs
- Use `@State` for view-local state, `@StateObject` for view models
- Prefer `@MainActor` for view models

### Commit Messages

Use clear and descriptive commit messages:

```
feat: Add keyboard shortcut for start recording
fix: Resolve CSV export issue with special characters
docs: Update README with installation instructions
refactor: Extract permission logic into PermissionManager
```

### Documentation

- Add documentation comments (`///`) for public methods and types
- Include parameter descriptions and return values
- Document any side effects or important behavior

## Security Considerations

Since this app monitors keyboard input, security is critical:

- **Never** add network functionality without discussion
- **Verify** permissions are validated before accessing system features
- **Review** all permission prompts and privacy implications
- **Keep** sensitive data handling transparent

## Review Process

All pull requests are reviewed by maintainers. We look for:

- Code quality and adherence to standards
- Security best practices
- Performance considerations
- Comprehensive changes (tests, docs if applicable)
- Clear commit history

## Questions?

Feel free to open an issue with the "question" label if you need help or clarification.

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing! 🎉
