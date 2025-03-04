# Contribution Guide

This guide provides instructions and guidelines for contributing to the DIVE25 Document Access System. Whether you're fixing bugs, adding features, improving documentation, or suggesting enhancements, your contributions are welcome.

## Getting Started

### Prerequisites

Before contributing, ensure you have:

1. Read the [Development Environment Setup](environment.md) guide
2. Familiarized yourself with the [System Architecture](../architecture/overview.md)
3. Read and agreed to our [Code of Conduct](#code-of-conduct)
4. Created a GitHub account and signed in

### Finding Issues to Work On

- Check the [Issue Tracker](https://github.com/organization/dive25/issues) for open issues
- Look for issues labeled `good-first-issue` if you're new to the project
- Review the [Project Roadmap](../releases/roadmap.md) for upcoming features

## Development Workflow

### 1. Set Up Your Development Environment

Follow the instructions in the [Development Environment Setup](environment.md) guide to set up your local environment.

### 2. Fork the Repository

1. Navigate to the [DIVE25 repository](https://github.com/organization/dive25)
2. Click the "Fork" button in the top-right corner
3. Clone your fork to your local machine:

```bash
git clone https://github.com/YOUR-USERNAME/dive25.git
cd dive25
```

4. Add the upstream repository as a remote:

```bash
git remote add upstream https://github.com/organization/dive25.git
```

### 3. Create a Branch

Create a new branch for your contribution:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

Follow these branch naming conventions:
- `feature/description` for new features
- `fix/description` for bug fixes
- `docs/description` for documentation changes
- `refactor/description` for code refactoring
- `test/description` for adding or improving tests

### 4. Implement Your Changes

While working on your changes:

1. Follow the [Coding Standards](#coding-standards)
2. Add or update tests to cover your changes
3. Keep your changes focused on a single issue
4. Regularly sync with the upstream repository:

```bash
git fetch upstream
git rebase upstream/main
```

### 5. Run Tests

Before submitting your changes, ensure all tests pass:

```bash
# Run backend tests
cd backend
npm test

# Run frontend tests
cd frontend
npm test

# Run integration tests
cd integration
./run-tests.sh
```

For more information about testing, see the [Testing Guide](testing.md).

### 6. Submit a Pull Request

When your changes are ready:

1. Push your branch to your fork:

```bash
git push -u origin feature/your-feature-name
```

2. Navigate to your fork on GitHub and click "New Pull Request"
3. Select your branch and provide a detailed description of your changes
4. Link related issues in your PR description using keywords like "Fixes #123" or "Addresses #456"
5. Submit the pull request

### 7. Code Review Process

After submitting your PR:

1. Automated tests will run on your code
2. Maintainers will review your code
3. Address any feedback or requested changes
4. Once approved, a maintainer will merge your changes

## Coding Standards

### General Guidelines

1. Write clean, readable, and maintainable code
2. Follow the existing code style and patterns
3. Document your code with comments where necessary
4. Keep functions small and focused
5. Use meaningful variable and function names

### JavaScript/TypeScript Guidelines

- Follow the [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- Use TypeScript for type safety
- Use async/await instead of callbacks
- Use ES6+ features when appropriate
- Run linting before committing:

```bash
npm run lint
```

### Java Guidelines

- Follow the [Google Java Style Guide](https://google.github.io/styleguide/javaguide.html)
- Use Java 11 features
- Use dependency injection when appropriate
- Document public APIs with Javadoc

### Frontend Guidelines

- Follow component-based architecture
- Use React hooks instead of class components
- Follow accessibility best practices
- Ensure responsive design works on various screen sizes
- Use the established design system

### Backend Guidelines

- Follow RESTful API design principles
- Document all APIs using OpenAPI specifications
- Handle errors gracefully
- Write comprehensive unit tests
- Follow security best practices

### Database Guidelines

- Follow database normalization principles
- Include indexes for frequently queried fields
- Document all schema changes
- Provide migration scripts for schema changes

## Documentation Guidelines

Documentation is crucial for the project. When contributing documentation:

1. Use clear, concise language
2. Use Markdown formatting consistently
3. Include screenshots or diagrams where helpful
4. Link to related documentation
5. Check for spelling and grammar errors

## Commit Message Guidelines

Follow the [Conventional Commits](https://www.conventionalcommits.org/) format:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

Where `type` is one of:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Changes that do not affect the meaning of the code
- `refactor`: Code changes that neither fix a bug nor add a feature
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Changes to the build process or auxiliary tools

Example:
```
feat(auth): add multi-factor authentication

- Added TOTP-based authentication
- Updated user settings to configure MFA
- Added unit tests for MFA functionality

Fixes #123
```

## Pull Request Guidelines

When submitting pull requests:

1. Provide a clear, descriptive title
2. Include a detailed description of changes
3. Link to relevant issues
4. Include screenshots for UI changes
5. Ensure all tests pass
6. Address any code review feedback

## Testing Guidelines

All code contributions should include appropriate tests:

1. Write unit tests for new functionality
2. Fix or add tests for bug fixes
3. Ensure all existing tests pass
4. Follow the guidelines in the [Testing Guide](testing.md)

## Code of Conduct

### Our Pledge

We as members, contributors, and leaders pledge to make participation in our community a harassment-free experience for everyone, regardless of age, body size, visible or invisible disability, ethnicity, sex characteristics, gender identity and expression, level of experience, education, socio-economic status, nationality, personal appearance, race, religion, or sexual identity and orientation.

We pledge to act and interact in ways that contribute to an open, welcoming, diverse, inclusive, and healthy community.

### Our Standards

Examples of behavior that contributes to a positive environment:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

Examples of unacceptable behavior:

- The use of sexualized language or imagery and unwelcome sexual attention or advances
- Trolling, insulting/derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate in a professional setting

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported to the project team at [conduct@dive25.example.org](mailto:conduct@dive25.example.org). All complaints will be reviewed and investigated and will result in a response that is deemed necessary and appropriate to the circumstances.

## License

By contributing to the DIVE25 Document Access System, you agree that your contributions will be licensed under the project's [LICENSE](../LICENSE).

## Additional Resources

- [Development Environment Setup](environment.md)
- [Testing Guide](testing.md)
- [API Development Guide](api.md)
- [System Architecture](../architecture/overview.md)
- [GitHub Flow Guide](https://guides.github.com/introduction/flow/)
- [How to Contribute to Open Source](https://opensource.guide/how-to-contribute/) 