# ScreenEditing for macOS

Native macOS screen annotation, whiteboard, cursor highlight, spotlight, and live cursor zoom application built with Swift 5.9 (`AppKit` + `SwiftUI` + `ScreenCaptureKit`) and a C++20 geometry engine (`CoreEngine`).

## Architecture

- **`Sources/CoreEngine`**: C++20 geometry and stroke engine (`ce_smooth_stroke`, `ce_constrain_line`, `ce_make_rect`, `ce_build_arrow_polygon`, `ce_build_shape_polygon`, hit-testing, marquee intersection, bounding box, and auto-erase expiration).
- **`Sources/PresentifyCore`**:
  - `Models/`: `AnnotationModels`, `AnnotationCanvasState`, and `AppSettings`.
  - `Shortcuts/`: `ShortcutManager` with 32 configurable global, annotation, and cursor shortcuts backed by Carbon `RegisterEventHotKey`.
  - `Annotation/`: `AnnotateOverlayController`, `AnnotatePanel`, `AnnotateCanvasView`, `AnnotateControlsView`, `AnnotateShortcutsView`, `ToastWindowController`, and `Screenshotter`.
  - `Cursor/`: `CursorHighlightWindowController`, `CursorSpotlightWindowController`, `CursorZoomWindowController`, and `ScreenCaptureManager`.
  - `UI/`: 6-tab `SettingsView` (`General`, `Annotate`, `Cursor`, `Shortcuts`, `Other apps`, `About`), `PresentifyMenuView`, `PresentifyDockMenuController`, and 6-page `WelcomeTourView`.
  - `App/`: `PresentifyAppController`.
- **`Sources/Presentify`**: Executable entry point launching `NSApplication` with `PresentifyAppController`.

## Build, Test & Package

```bash
swift build
swift test
swift build -c release
bash scripts/bundle-app.sh
```

Running `bash scripts/bundle-app.sh` produces the self-contained macOS application bundle at `build/ScreenEditing.app`.
