# Changelog

All notable changes to this project will be documented in this file.

## [1.1.0] - 2026-06-29

### Added
- **Dynamic Modifier Key Selection**: Introduced support for selecting either **Control (⌃)** or **Option (⌥)** for both Left (Switch) and Right (Cycle) action blocks in the Settings UI.
- **MacBook Auto-Detection**: Integrated dynamic battery presence detection via `IOKit` (`IOPSCopyPowerSourcesInfo`). If a battery is detected (indicating a MacBook, which lacks a physical Right Control key), the default Right action modifier key is automatically configured to **Option (⌥)**. On desktop Macs, it defaults to **Control (⌃)**.
- **Interactive UI Pickers**: Replaced static "Left Control" and "Right Control" headers in `SettingsView` with clean, responsive, inline drop-down `Picker` controls that preserve the custom monochrome glassmorphism aesthetic.

### Changed
- **English Code Comments & Build Logs**: Fully translated all code comments, logs, and `build.sh` script outputs from Russian to English for enhanced codebase standardization.

### Fixed
- Fixed raw event tap handling in `EventTapManager` to dynamically support chosen keycodes (`59`, `62`, `58`, `61`) and low-level device-dependent modifier flags.
