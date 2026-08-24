# Contributing to BunnyBar

Thanks for considering contributing!

## How to Open an Issue

- Clear title
- Steps to reproduce
- Expected vs actual behavior

## Pull Requests

- Target branch: main
- One feature per PR

## Development Setup

1. Clone the repository and enter its root directory.
2. Open the canonical project at `BunnyBar/BunnyBar.xcodeproj` in Xcode.
3. Select the `BunnyBar` scheme and build or run it on **My Mac**.

For a command-line Debug build, use the same command documented in README:

```sh
xcodebuild -project BunnyBar/BunnyBar.xcodeproj \
  -scheme BunnyBar -configuration Debug \
  -derivedDataPath build/DerivedData build
```

The app target explicitly uses `BunnyBar/Sources/BunnyBar`. Do not create a new
Xcode project or add the historical top-level `Sources/BunnyBar` tree to the
target.

## Code Style

- Follow Swift standard naming conventions
- Use meaningful variable and function names
- Add comments for complex logic
- Run both Debug and Release builds before opening a pull request
