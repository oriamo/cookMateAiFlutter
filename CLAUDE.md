# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Test Commands
- you cant run tests on the terminal because flutter insint on this terminal

## Code Style Guidelines
- **Imports**: Group imports by Flutter, third-party, and project files with blank lines between
- **Naming**: camelCase for variables/methods, PascalCase for classes/enums, snake_case for files
- **Types**: Always use explicit types for public APIs, prefer final for immutable variables
- **Error handling**: Use try/catch with specific exceptions and provide meaningful error messages
- **State management**: Use Riverpod for state management, follow provider pattern
- **Documentation**: Add /// doc comments for public APIs explaining purpose and parameters
- **UI patterns**: Prefer composition, extract reusable widgets, use const constructors
- **Organization**: Keep files focused and under 300 lines, follow feature-first organization
- **Tests**: Write widget and unit tests for critical functionality

## User prefrences
- after implementing a feature or a fix run git add . and git commit with good commentary