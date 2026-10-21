# Kōtoe

A native Apple flashcard study app. Organise cards into subjects and sets,
then review them in a tap-to-flip study session, marking each card **Got It**
or **Again**.

Kōtoe runs on iOS, iPadOS and macOS, stores its data locally with SwiftData,
and syncs through your own iCloud account.

## Features

- **Subjects and sets** — a two-level hierarchy, with per-subject and per-set
  icons and colours.
- **Study session** — tap to flip a card, then mark it *Got It* or *Again*;
  missed cards cycle back to the end of the queue.
- **Rich card sides** — text, photos, hand-drawn PencilKit canvases and PDF
  documents.
- **iCloud sync** — SwiftData mirrors the store through CloudKit, so every
  device sees the same library.
- **Offline first** — the app never needs a network connection; card media is
  stored in the app's iCloud Drive container.
- **Localised** — English, German, Spanish, French and Japanese.

## Requirements

| | |
| --- | --- |
| Xcode | 27.1 or newer |
| Deployment target | iOS 27.0, iPadOS 27.0, macOS 27.0 |
| Swift | 5.0 language mode |
| Dependencies | None |

The project has no third-party packages, CocoaPods dependencies or generated
code.

## Building

`xcode-select` on some machines points at the Command Line Tools, so set
`DEVELOPER_DIR` explicitly:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

Build for the iOS Simulator:

```sh
xcodebuild -project "Kōtoe.xcodeproj" -scheme "Kōtoe" \
  -destination 'generic/platform=iOS Simulator' build
```

Build for macOS:

```sh
xcodebuild -project "Kōtoe.xcodeproj" -scheme "Kōtoe" \
  -destination 'platform=macOS,arch=arm64' build
```

Both platforms should be built before shipping a change, because the drawing
editor and the card editors use platform-specific code paths.

Open the project in Xcode with:

```sh
open "Kōtoe.xcodeproj"
```

## Project layout

```
Localizable.xcstrings        UI copy for en, de, es, fr, ja
Kotoe/
  FlashApp.swift             @main app, SwiftData ModelContainer
  ContentView.swift          Subject list (root screen)
  Sync/
    CloudKitSyncMonitor.swift CloudKit event observer + sync status
  Media/
    MediaStore.swift         iCloud Drive file storage for card media
  Models/
    Subject.swift            top level: subject
    FlashcardSet.swift       flashcards belonging to a subject
    Flashcard.swift          one card; front/back accessors
    FlashcardSide.swift      content payload + PencilKit helpers
  Views/
    SubjectView.swift        subject detail, sets, notes, "Study All"
    StudyView.swift          study session + FlipCard
    FlashcardSetEditView.swift set editor, card editor, side editor
    FlashcardSideContentView.swift rendering, media loading, canvases
    PDFViewer.swift          PDFKit wrapper + full document viewer
    OpenSourceLicensesView.swift in-app license notice
    Helper/
      PlatformModifiers.swift cross-platform view modifiers
      IconButton.swift       shared button + `if` modifier
      Theme.swift            brand colors, card surfaces, shared UI pieces
      CreateItemSheet.swift  shared "create subject / create set" prompt
      AppearanceEditor.swift icon + color picker for subjects and sets
      LocalizedCounts.swift  pluralized subject/set/card counts
```

The Xcode project uses a file-system-synchronized group, so any `.swift`
file added under `Kotoe/` is compiled automatically. The `LICENSE` file at the
repository root is the single source of truth for the license text: it is
copied into the app bundle, and `Kotoe/Views/OpenSourceLicensesView.swift`
reads it at runtime to show the license name, copyright line and full text, so
the in-app copy can never drift from the repository.

## Localization

All UI copy lives in `Localizable.xcstrings`. The source language is English;
German, Spanish, French and Japanese are machine translated and have not been
reviewed by native speakers. The app shows a disclaimer about this in the
library footer whenever the app language is not English.

## License

Kōtoe is released under the MIT License. The full text is in
[LICENSE](LICENSE), and it is the only copy — please do not duplicate it.
