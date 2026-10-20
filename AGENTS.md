# AGENTS.md

> **Keep this file current.** Any agent or model that changes this codebase
> must update `AGENTS.md` in the same change. See
> [Maintaining this file](#maintaining-this-file).

## What this app is

**Kōtoe** (product name; source folder is `Kotoe/`) is a native Apple flashcard
study app. Users organize cards into subjects and sets, then review them in a
tap-to-flip study session, marking each card **Got It** or **Again** (missed
cards cycle back to the end of the queue). Cards can have text, photo, or
hand-drawn (PencilKit) content on each side. Data is stored locally with
SwiftData and synced through the user's iCloud/CloudKit account.

It is an early-stage app: the UI and data model for the core loop exist; spaced
repetition scheduling, archiving, import/export, search, and tests do not.

## Platform & toolchain

| Item | Value |
| --- | --- |
| UI | SwiftUI (no UIKit/AppKit view controllers except PencilKit wrappers) |
| Persistence | SwiftData (`@Model`), CloudKit sync enabled (`.automatic`) |
| Targets | iOS, iPadOS, macOS, visionOS (`TARGETED_DEVICE_FAMILY = 1,2,7`) |
| Deployment target | 27.0 for iOS and macOS |
| Swift | 5.0 language mode |
| Xcode | 27.1 (`objectVersion = 77`) |
| Bundle ID | `com.erebur.kotoe`, team `XMGF5HVWMW` |
| Dependencies | None. No SPM packages, CocoaPods, or generated code. |
| Libraries used | SwiftUI, SwiftData, PencilKit, PhotosUI |

The Xcode project uses a **file-system-synchronized group**, so any `.swift`
file added anywhere under `Kotoe/` is compiled automatically. Do **not**
hand-edit `Kōtoe.xcodeproj/project.pbxproj` to add files.

The project/scheme name contains a macron (`Kōtoe`). Always quote it in shell
commands.

## Build & run

`xcode-select` on this machine points at CommandLineTools, so `xcodebuild`
fails unless `DEVELOPER_DIR` is set explicitly:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Build the app (both verified to succeed):

```sh
# iOS simulator
xcodebuild -project "Kōtoe.xcodeproj" -scheme "Kōtoe" \
  -destination 'generic/platform=iOS Simulator' build

# macOS
xcodebuild -project "Kōtoe.xcodeproj" -scheme "Kōtoe" \
  -destination 'platform=macOS,arch=arm64' build
```

Open in Xcode: `open "Kōtoe.xcodeproj"`.

Available simulators include `iPhone 17`, `iPad (A16)`, and `iPad Air 11-inch
(M4)` (iOS 27.0). List them with `xcrun simctl list devices available`; boot with
`xcrun simctl boot "iPhone 17"` and launch with
`xcrun simctl launch booted com.erebur.kotoe`. The macOS app is a standard app
bundle in the build products directory.

There is no test target, linter, formatter, or CI configuration. The only
verification step is a successful build for each platform you touch. Building
for **both macOS and iOS** matters because platform-specific code paths exist.

## Repository layout

```
Kotoe/
  FlashApp.swift                 @main app, SwiftData ModelContainer
  ContentView.swift              Subject list (root screen)
  Models/
    Subject.swift                top level: subject
    FlashcardSet.swift           flashcards belonging to a subject
    Flashcard.swift              one card; front/back accessors
    FlashcardSide.swift          content payload + PencilKit helpers
  Views/
    SubjectView.swift            subject detail, sets, notes, "Study All"
    StudyView.swift              study session + FlipCard
    FlashcardSetEditView.swift   set editor, card editor, side editor
    FlashcardSideContentView.swift  rendering, image compression,
                                    PencilKit canvases, DrawingEditorView
    Helper/
      PlatformModifiers.swift    cross-platform view modifiers
      IconButton.swift           shared button + `if` modifier
      Theme.swift                brand colors, card surfaces, shared UI pieces
      CreateItemSheet.swift      shared "create subject / create set" prompt
      AppearanceEditor.swift     icon + color picker for subjects and sets
```

## Data model

Hierarchy, all cascade-deleted from the parent:

```
Subject ──< FlashcardSet ──< Flashcard ──< FlashcardSide (role: front | back)
```

- Every `@Model` stored property has a **default value**, and relationships are
  **optional arrays** (`[Flashcard]?`). Keep it that way: CloudKit-backed
  SwiftData requires optional or defaulted attributes.
- Do not add `@Attribute(.unique)` — CloudKit does not support unique
  constraints.
- A side's payload is a `Data` blob chosen by `contentType`:
  - `.richText` → `richTextData` (RTF; currently edited as plain text)
  - `.image` → `imageData` (JPEG, downscaled to 1600 px, quality 0.85)
  - `.drawing` → `drawingData` (`PKDrawing.dataRepresentation()`)
  Only one payload is populated at a time; use the `updateRichText`,
  `updateImage`, `updateDrawing`, and `clearContent` helpers.
- `isArchived` and `position` exist on all levels. `sortedFlashcardSets` and
  `sortedFlashcards` filter archived items and sort by `position`. There is no
  archive UI yet, but queries and computed properties already respect the flag.
- `Subject` and `FlashcardSet` store `iconName` (SF Symbol) and `tintIndex`
  (index into `KotoeTheme.palette`), both optional. `nil` means "automatic":
  subjects derive an icon/color from the name, sets use the stack symbol and
  inherit the subject's color. Use the `style` computed property to render them
  and `effectiveTintIndex` to preselect the appearance editor.
- `createdAt` / `modifiedAt` / `lastAccessedAt` are plain properties updated
  **manually** in the views. There are no automatic hooks; update the parent's
  `modifiedAt` when mutating children.
- Side order in `Flashcard.sides` is not meaningful — always use `front` /
  `back` or `setFront` / `setBack`.

## Conventions

- 4-space indentation, roughly 80-column wrapping (SwiftFormat-like style:
  wrapped arguments one per line, trailing commas not used).
- Group each type with `// MARK: - <Name>` sections; keep view bodies small by
  extracting `private var xxxSection: some View` computed properties.
- Views take SwiftData models via `@Bindable`, read data via `@Query` or the
  model's `sorted*` helpers, and mutate through `@Environment(\.modelContext)`.
  Call `try? modelContext.save()` (or handle the error like existing code) after
  structural changes.
- File headers follow the existing 5-line `//  File.swift` / project / author /
  date comment. Match the surrounding files.
- Prefer the shared helpers in `Views/Helper/` over new one-offs; extend
  `PlatformModifiers.swift` when a modifier differs per platform.
- Subject/set appearance is edited through `AppearanceEditor`; render icons with
  `model.style` and tint card/background surfaces with `style.tint`
  (`cardSurface(tint:)`, `AmbientBackground(tint:)`) instead of hardcoding
  `KotoeTheme.accent`.
- Keep platform-specific code behind `#if os(macOS)` / `#else`. Examples:
  `inlineNavigationBarTitle()` (no inline titles on macOS),
  `editorCover(...)` (`fullScreenCover` is iOS-only), and `NSImage` vs `UIImage`.
- Avoid force unwraps, except existing UI defaults; handle failures with `guard`
  or `try?`, and log persistence failures with `print`.
- Previews pass an in-memory container listing **all four models**; keep that
  pattern for new previews.

## Cross-platform gotchas

- `PKCanvasView` and `PKToolPicker` are iOS-only. macOS drawing uses the custom
  `DrawingCanvasView: NSView` in `FlashcardSideContentView.swift`, which writes
  the same `PKDrawing` format so drawings sync across devices. Any drawing
  changes must keep both paths compatible.
- iOS presents the drawing editor in a `fullScreenCover`, macOS in a `sheet`,
  via `editorCover`.
- macOS has no `EditButton` swipe-to-delete, so card deletion is also exposed
  through context menus. Maintain keyboard/mouse affordances when adding
  gesture-only features.
- Non-scrolling screens (like `StudyView`) get an opaque window toolbar on
  macOS, unlike `ScrollView`-based screens whose tinted backdrop shows through.
  Apply `.toolbarBackground(.hidden, for: .windowToolbar)` under
  `#if os(macOS)` to keep the titlebar consistent.
- Images render through `NSImage`/`UIImage` helpers, and drawings are rendered
  in light mode so ink matches the white canvas.

## Where to change what

- Add a screen field: extend the model, then the relevant form in
  `SubjectView` / `FlashcardSetEditView`.
- Change study behavior (queue, scoring, shuffling): `StudyView.swift`.
- Change card rendering or add a content type: `FlashcardSideContentView.swift`
  plus the `FlashcardContentType` enum and the side editor's picker.
- Change persistence/schema: `FlashApp.swift` schema list plus the models;
  remember CloudKit defaults and that local stores may need a migration.
- New subject/set flows and list styling: `ContentView.swift`,
  `SubjectView.swift`.
- Change icon/color choices or the appearance UI: `Theme.swift`
  (`subjectSymbols`, `setSymbols`, `palette`) and `AppearanceEditor.swift`.

## Known gaps (safe next steps)

- No spaced-repetition scheduling: sessions are a simple re-queue, with no
  review intervals, due dates, or per-card history.
- No archive UI despite `isArchived` plumbing; no reordering of subjects/sets
  (only cards can be moved).
- No import/export (CSV/Anki), search, tags, or localization (English only).
- Rich text is stored as RTF but edited and rendered as plain text.
- No error UI when the model container or CloudKit sync fails
  (`fatalError` on container creation, `print` on save).
- The push-notification entitlement and background mode exist but nothing uses
  them. No tests.

## Maintaining this file

This document is the shared brief for every future agent/model working here, so
**every change that affects it must update it**. Treat it as part of the
definition of done: a change is incomplete if `AGENTS.md` now describes the
codebase inaccurately.

Update it when you:

- add, remove, or rename a file, folder, screen, or model (update **Repository
  layout** and **Where to change what**);
- change a model's properties, relationships, delete rules, or persistence
  behavior (update **Data model**);
- add a dependency, target, platform, deployment target, build step, or test
  command (update **Platform & toolchain** and **Build & run**);
- establish or change a coding convention, helper, or platform workaround
  (update **Conventions** and **Cross-platform gotchas**);
- change behavior or tooling that affects how work is verified;
- close one of the **Known gaps**, or discover a new limitation or gotcha worth
  warning the next agent about.

Guidelines for edits:

- Prefer editing the existing section over appending a new one; keep the file
  short and scannable.
- Describe the current state and the *why*, not a changelog or history. Do not
  add dated entries.
- Keep commands copy-pasteable and verified; note the platform they apply to.
- Remove stale statements rather than leaving contradictions.
- Match the surrounding Markdown style (sentence case headings, wrapped prose,
  tables for facts).
