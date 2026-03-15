# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).



## [0.0.7] - 2026-03-15

### Changed
- Updated Vosk Android dependency to 0.3.75 to support 16KB page size.

## [0.0.6] - 2026-01-22

### Changed
- Configured CLI download URLs to point to the official repository for native binaries.
- Improved CLI installation flow and error reporting.

## [0.0.5] - 2026-01-22

### Fixed
- Fixed CLI executable name to match package name (`vosk_flutter_service`).
- Updated internal package name constants in CLI tool.

## [0.0.4] - 2026-01-22

### Changed
- Excluded large iOS and MacOS native binaries from the pub.dev package to comply with the 100MB size limit.
- Updated the CLI tool to support downloading and installing native binaries for iOS and MacOS.
- Updated `README.md` with instructions for native binaries installation.

## [0.0.3] - 2026-01-22

> [!IMPORTANT]
> **Technical Note**: Previous versions had an incomplete iOS implementation due to missing native frameworks in the `ios/Frameworks` directory and a casing discrepancy in the method bridge. We apologize for these technical omissions which have now been fully resolved.

### Fixed
- Resolved iOS microphone input issue by adding explicit `AVAudioSession` configuration.
- Fixed critical method name mismatch between Dart and Swift.
- Added robust debug logging for iOS (NSLog) and Dart sides to track audio data flow.
- Optimized `SpeechService` listener logic in Dart for better performance and reliability.
- Fixed various linting issues across the codebase.

## [0.0.2] - 2026-01-14

### Changed
- Updated repository URL to `https://github.com/dhia-bechattaoui/vosk-flutter-service`.

## [0.0.1] - 2026-01-05

### Changed
- **BREAKING**: Renamed package to `vosk_flutter_service`.
- Migrated Android build to Kotlin DSL.
- Updated `record` dependency to v6 in example app.
- Enforced strict type safety (0 analysis issues).

### Fixed
- Resolved all analysis issues.
- Updated AGP/Gradle versions.

[0.0.7]: https://github.com/dhia-bechattaoui/vosk-flutter-service/compare/v0.0.6...v0.0.7
[0.0.6]: https://github.com/dhia-bechattaoui/vosk-flutter-service/compare/v0.0.5...v0.0.6
[0.0.5]: https://github.com/dhia-bechattaoui/vosk-flutter-service/compare/v0.0.4...v0.0.5
[0.0.4]: https://github.com/dhia-bechattaoui/vosk-flutter-service/compare/v0.0.3...v0.0.4
[0.0.3]: https://github.com/dhia-bechattaoui/vosk-flutter-service/compare/v0.0.2...v0.0.3
[0.0.2]: https://github.com/dhia-bechattaoui/vosk-flutter-service/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/dhia-bechattaoui/vosk-flutter-service/releases/tag/v0.0.1