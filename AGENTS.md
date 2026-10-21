# AGENTS.md

> **Keep this file current.** Any agent or model that changes this codebase
> must update `AGENTS.md` in the same change. See
> [Maintaining this file](#maintaining-this-file).

## What this app is

**Kōtoe** (product name; source folder is `Kotoe/`) is a native Apple flashcard
study app. Users organize cards into subjects and sets, then review them in a
tap-to-flip study session, marking each card **Got It** or **Again** (missed
cards cycle back to the end of the queue). Cards can have text, photo,
hand-drawn, or PDF content on each side. Data is stored locally with
SwiftData and synced through the user's iCloud/CloudKit account.

It is an early-stage app: the UI and data model for the core loop exist; spaced
repetition scheduling, archiving, export, search, and tests do not.

## Platform & toolchain

| Item | Value |
| --- | --- |
| UI | SwiftUI (no UIKit/AppKit view controllers except PencilKit wrappers) |
| Persistence | SwiftData (`@Model`), CloudKit sync enabled (`.automatic`) |
| Targets | iOS, iPadOS, macOS (`TARGETED_DEVICE_FAMILY = 1,2`) |
| Deployment target | 27.0 for iOS and macOS |
| Swift | 5.0 language mode |
| Xcode | 27.1 (`objectVersion = 77`) |
| Bundle ID | `com.erebur.kotoe`, team `XMGF5HVWMW` |
| Localization | String Catalog; English source plus de, es, fr, ja |
| Dependencies | None. No SPM packages, CocoaPods, or generated code. |
| Libraries used | SwiftUI, SwiftData, PencilKit, PhotosUI, PDFKit, ImageIO |

The Xcode project uses a **file-system-synchronized group**, so any `.swift`
file added anywhere under `Kotoe/` is compiled automatically. Do **not**
hand-edit `Kōtoe.xcodeproj/project.pbxproj` to add files. The exceptions are
the files that sit at the project root (outside the synchronized group) and
are added to the target explicitly: `Localizable.xcstrings` and `LICENSE`.

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

## Demo & screenshot workflow

There is no preview harness. To inspect a specific screen or compare a visual
change, build a throwaway copy of the project instead of modifying the working
tree.

1. Copy the repo to a temp directory and keep the demo build separate:

```sh
DEMO=$(mktemp -d)
rsync -a --exclude .git ./ "$DEMO/"
```

2. In the copy, change `Kotoe/FlashApp.swift` so the target screen is the root,
   or auto-present it with `.task` / `.onChange`. Use the existing store through
   `@Query` for read-only screens, or an in-memory container with sample models
   when the screen writes data. Example — open the first set editor in a sheet:

```swift
struct DemoRoot: View {
    @Query(sort: \FlashcardSet.name) private var sets: [FlashcardSet]
    @State private var show = false

    var body: some View {
        Color.clear
            .sheet(isPresented: $show) {
                if let set = sets.first {
                    FlashcardSetEditView(flashcardSet: set)
                }
            }
            .onChange(of: sets.count, initial: true) {
                if !sets.isEmpty { show = true }
            }
    }
}
```

For screens that take models directly (for example `StudyView`), create
`Flashcard`/`FlashcardSide` objects in the demo and pass them in.

3. Build the copy with its own DerivedData and run it:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
cd "$DEMO"
xcodebuild -project "Kōtoe.xcodeproj" -scheme "Kōtoe" \
  -destination 'platform=macOS,arch=arm64' \
  -derivedDataPath ./dd build
open ./dd/Build/Products/Debug/Kōtoe.app
```

4. Find the window ID and bounds with CoreGraphics. This needs no Accessibility
   permission:

```sh
cat > "$DEMO/windows.swift" <<'EOF'
import CoreGraphics

let list = CGWindowListCopyWindowInfo(
    [.optionOnScreenOnly, .excludeDesktopElements],
    kCGNullWindowID
) as? [[String: Any]] ?? []

for window in list {
    let owner = window[kCGWindowOwnerName as String] as? String ?? ""
    if owner.contains("toe") {
        let id = window[kCGWindowNumber as String] as? Int ?? 0
        let name = window[kCGWindowName as String] as? String ?? ""
        let bounds = window[kCGWindowBounds as String] as? [String: Any] ?? [:]
        print(id, "|", name, "|", bounds)
    }
}
EOF
swift "$DEMO/windows.swift"
```

5. Capture the window, or a screen region:

```sh
screencapture -x -l <windowID> "$DEMO/shot.png"
screencapture -x -R x,y,width,height "$DEMO/region.png"
```

`-l` captures the window even when it is covered. `-R` captures the screen, so
bring the window to the front first. Save images outside the repo. To compare
states, change the copy, rebuild, and capture again.

Notes:

- Quit other `Kōtoe` instances first
  (`pkill -f "DerivedData/K.*toe"`). macOS keeps one instance per bundle ID,
  so a stale build can keep the old window.
- **Never let a demo sync.** A demo container must pass
  `cloudKitDatabase: .none` **and** `isStoredInMemoryOnly: true`.
  `cloudKitDatabase` defaults to `.automatic`, so a container that only sets
  `isStoredInMemoryOnly` still opens the real store, writes the sample data
  into it, and exports it to iCloud.
- Give the demo copy its own bundle ID and strip the iCloud entitlements
  (`icloud-services`, `ubiquity-container-identifiers`) and
  `NSUbiquitousContainers` from `Info.plist`. A non-sandboxed demo can still
  resolve the real ubiquity container by identifier and write sample media into
  the user's iCloud Drive. After a demo, check
  `~/Library/Mobile Documents/iCloud~com~erebur~kotoe` and delete anything the
  demo created.
- A demo that falls back to local media storage writes into
  `~/Library/Application Support/Media` (the folder is shared by every
  non-sandboxed build). Delete it after the demo run.
- macOS restores the last window frame from the user defaults, which overrides
  `Scene.defaultSize`. A demo that needs a specific window size has to set it
  with `NSWindow.setContentSize` after the window appears.
- `osascript` clicks and keystrokes are blocked here with
  `osascript is not allowed assistive access`. Do not try to drive the UI;
  make the target screen the root or auto-present it.
- Never commit the demo `FlashApp.swift`, sample data, build output, or
  screenshots. The committed screenshots in `docs/images/` are converted to
  WebP and belong in the repository; everything else stays outside it.
- For iOS, boot a simulator and use
  `xcrun simctl io booted screenshot "$DEMO/shot.png"`. Make the target screen
  the root in the copy for the same reason.

## Worktree workflow

OpenCode sessions may run in a git worktree under
`~/.local/share/opencode/worktree/...`. The worktree shares history with the
main checkout but usually has a detached HEAD. When the work is finished,
transfer it to the main checkout instead of leaving it in the worktree.

**Agents never commit, merge, or close a worktree on their own.** Do not run
`git commit`, `git merge`, `git cherry-pick`, `git tag`, or
`git worktree remove` without an explicit go-ahead from the user; the user
may want to review, amend, or reword the work first. When the task is
finished, stop and ask if you should commit.

Run the steps below only after the user agrees. If the user answers with
their own wording, treat it as the approval for the whole sequence.

1. From the worktree, commit everything and note the SHA(s):

```sh
WORKTREE=$(pwd)
git add -A
git commit -m "Describe the change"
git rev-parse HEAD
```

If the work spans several commits, list them with `git log --oneline` and
cherry-pick them in order.

2. Cherry-pick into the main checkout:

```sh
MAIN=/Users/erebur/Developer/Kotoe
git -C "$MAIN" cherry-pick <SHA>
```

3. Verify the main checkout builds and the log/status look right:

```sh
git -C "$MAIN" log --oneline -3
git -C "$MAIN" status
```

4. Close the worktree. If the OpenCode session is running inside it, move the
   session to the main checkout first (the `session_move` tool); removing a
   worktree while a session uses it breaks that session. Then remove it:

```sh
git -C "$MAIN" worktree remove "$WORKTREE"
git -C "$MAIN" worktree list
```

Prefer `cherry-pick` for one-off transfers. Use `git merge <SHA>` instead when
the worktree commits should keep their branch history in the main checkout.

## Versioning & releases

- A larger feature bumps both version fields in `Kōtoe.xcodeproj/project.pbxproj`
  (all configurations): `MARKETING_VERSION` (for example `1.1` → `1.2`) and
  `CURRENT_PROJECT_VERSION` (build number). Include the bump in the feature
  commit, then tag that commit in the main checkout:
  `git tag -a v1.2 -m "Describe the feature"`. The version string carries no
  prefix, and the tag matches it.
- Bump for new content types, storage or sync layers, new screens or flows, and
  model changes. Docs, copy changes, and small fixes do not need a bump.
- Tag only commits that are in the main checkout, after transferring the work
  from a worktree; tags created in a worktree are easy to lose. Never move or
  reuse an existing tag — bump the version again instead. Tags are part of the
  same approval rule: ask before creating one.
- Check the current values with
  `grep -n "MARKETING_VERSION\|CURRENT_PROJECT_VERSION" "Kōtoe.xcodeproj/project.pbxproj"`
  and list existing tags with `git tag -l`.

## Repository layout

```
LICENSE                          MIT license text; bundled into the app
README.md                        project overview, screenshots, stats, roadmap
Localizable.xcstrings            UI copy for en, de, es, fr, ja
docs/images/                     Screenshots referenced by README.md
Kotoe/
  FlashApp.swift                 @main app, SwiftData ModelContainer
  ContentView.swift              Subject list (root screen)
  Control/
    LocalizedCounts.swift        pluralized subject/set/card counts
    Media/
      MediaStore.swift           iCloud Drive file storage for card media
    Sync/
      CloudKitSyncMonitor.swift  CloudKit event observer + sync status
  Import/
    TextCardImporter.swift       pasted text → cards (Quizlet TSV and friends)
    ImportedFile.swift           reads a picked file, detects its content
  Models/
    Subject.swift                top level: subject
    FlashcardSet.swift           flashcards belonging to a subject
    Flashcard.swift              one card; front/back accessors
    FlashcardSide.swift          content payload + PencilKit helpers
  Views/
    FlashcardSetEditView.swift   set editor, card editor, side editor
    CardImportView.swift         bulk import sheet: paste text, preview, import
    FlashcardSideContentView.swift  rendering, media loading,
                                    PencilKit canvases, DrawingEditorView
    Theme.swift                  brand colors, card surfaces, shared UI pieces
    Helper/
      PlatformModifiers.swift    cross-platform view modifiers
      AppearanceEditor.swift     icon + color picker for subjects and sets
      CreateItemSheet.swift      shared "create subject / create set" prompt
      PDFViewer.swift            PDFKit wrapper + full document viewer
      If.swift                   shared `if` view modifier
      Clipboard.swift            pasteboard access for the card import
    Structure/
      SubjectView.swift          subject detail, sets, notes, "Study All"
      StudyView.swift            study session + FlipCard
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
- A side's payload is chosen by `contentType`:
  - `.richText` → `richTextData` (RTF; currently edited as plain text)
  - `.image` → `mediaFileName` (original JPEG/HEIC/PNG file)
  - `.drawing` → `mediaFileName` (`PKDrawing.dataRepresentation()`, vector)
  - `.pdf` → `mediaFileName` (imported PDF document)
  `mediaFileName` names a file in `MediaStore`, not a CloudKit attribute.
  Cards created before the media store still read legacy `imageData` /
  `drawingData` blobs. Only one payload is populated at a time; use
  `updateRichText`, `updateImage`, `updateDrawing`, `updatePDF`, and
  `clearContent` (which also deletes the file).
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

## Card editing & import

`FlashcardSetEditView` lists the cards of a set. **Import** opens
`CardImportView`, **Add Card** opens the card editor for a new card, and a
card row opens the editor for an existing one.

- The card editor (`FlashcardEditorView`) has a footer with **Save** and
  **Next Card**. **Next Card** creates an empty card at the end of the set
  and *replaces* the open editor in the navigation path
  (`path[path.count - 1] = card`), so the back button still returns to the
  set instead of walking through every card that was added.
- Each side picks what it holds with a styled segmented control: **Text**,
  **Drawing** and **File**. The file entry covers images and PDFs, because
  the file itself decides which one a side ends up with; the model still
  stores `.image` and `.pdf` separately, and the picker maps between the
  two. A side that holds a file shows the file controls, everything else is
  refused with an alert.
- The file picker accepts every file (`UTType.item`); `ImportedFile` decides
  what the file becomes — a PDF stays a PDF, an image is stored as an image,
  a text file becomes text. Picking a file also switches the side's
  `contentType` to match.
- The file tab keeps the native gallery picker (`PhotosPicker`) next to the
  file picker. Images are decoded with ImageIO, so every format the system
  supports (JPEG, PNG, HEIC, GIF, TIFF, WebP) renders.
- Bulk import parses pasted or imported text with `TextCardImporter`: one
  card per line, term and answer separated by a tab (Quizlet), a dash, or a
  colon. The separator is detected from the text, `\n` inside a field is
  unescaped, and lines without a separator become cards with a front only.
  The sheet shows a preview of the first cards before anything is created.
- Reading the pasteboard on iOS shows the system paste prompt, so only read
  it from a user action. `Clipboard.hasText` is safe to read while drawing;
  `Clipboard.text` is not.

## iCloud sync

SwiftData mirrors the store through CloudKit automatically
(`cloudKitDatabase: .automatic`, container `iCloud.com.erebur.kotoe`, declared
in `Kōtoe.entitlements`). Nothing in the app talks to CloudKit directly.

- The mirror imports on launch and when CloudKit delivers a silent push. Silent
  pushes are best effort: they are skipped in Low Power Mode, never reach a
  force-quit app, and the macOS app only syncs while it is running. Closing the
  window does not quit it, so a long-idle app can show stale data until it is
  relaunched.
- `CloudKitSyncMonitor` observes
  `NSPersistentCloudKitContainer.eventChangedNotification`, logs failed
  setup/import/export operations with `print`, and drives the "Synced …" /
  "iCloud sync failed" line in the library footer. SwiftData posts these
  notifications even though it never exposes its container. The line is
  pinned to the bottom of the library screen with a `safeAreaInset`, not
  part of the scroll view, so it stays readable at any scroll position.
- Imports run through `NSPersistentStoreRemoteChange` and normally refresh
  `@Query` results without extra work. When data looks missing, relaunch before
  assuming it never synced — TN3164 lists this first.
- Card media is not part of the SwiftData record. `MediaStore` writes photos,
  drawings, and PDFs to the app's iCloud Drive container (`Documents/Media`),
  so full-resolution files stay clear of CloudKit's 1 MB record limit and sync
  through iCloud Drive. The model only carries the file name, so a record can
  arrive on another device before its file. Views load media through
  `MediaStore.loadData(named:)` / `loadURL(named:)`, which wait for the
  iCloud download; `hasFile(named:)` also counts `.name.icloud` placeholders.
- The iCloud Documents capability is declared in `Kōtoe.entitlements`
  (`CloudDocuments` + `ubiquity-container-identifiers`) and
  `NSUbiquitousContainers` in `Info.plist`. The document scope is public, so
  the `Media` folder is visible in iCloud Drive / Files. When iCloud Drive is
  unavailable, `MediaStore` falls back to Application Support on that device.
- Cascade deletes are applied by the deleting device and then exported. A child
  whose parent ends up `nil` is invisible: the library only counts reachable
  sets and cards, so it looks like data loss. Such orphans were found in the
  store and repaired by hand; there is still no automatic repair pass or UI.
- Do not repair data by opening the store from a separate tool. The mirror does
  not see those writes as changes, and the next import overwrites them. Run
  repairs through the app's own `ModelContainer` (for example a temporary
  `.task`), let the export finish, then remove the code.
- CloudKit's development schema is separate from production. TestFlight and App
  Store builds only see the production environment.

## Localization

- All UI copy lives in `Localizable.xcstrings` at the project root. The
  project sets `LOCALIZATION_PREFERS_STRING_CATALOGS = YES`; the catalog's
  source language is English and it ships German, Spanish, French, and
  Japanese. Add every new key to all five languages, otherwise the string
  falls back to English.
- **Keys use `{view}.{section}.{enShorthand}`**, e.g.
  `contentView.emptyState.title`, `studyView.progress.cardsLeft`,
  `appearanceEditor.footer.reset`. The first segment is the screen or shared
  group (`contentView`, `subjectView`, `studyView`, `setEditView`,
  `cardEditor`, `sideEditor`, `sideContent`, `drawingEditor`,
  `appearanceEditor`, `shared`), the second the area of that screen, and the
  last a camelCase shorthand of the English text. Reuse a key only when the
  English wording and meaning are identical; otherwise add a new key. Never use
  the English sentence itself as the key.
- Xcode compiles the catalog into per-language `Localizable.strings` and
  `Localizable.stringsdict` files at build time. No `.lproj` folders are checked
  in. `knownRegions` in `project.pbxproj` lists en, de, es, fr, ja, Base; keep it
  in sync when adding a language.
- SwiftUI `Text`, `Label`, `Button`, `TextField`, `SectionHeader`, `.help`,
  `navigationTitle`, and `confirmationDialog` take a `LocalizedStringKey`, so a
  literal key localizes automatically. When a key needs arguments, pass the
  English text as `defaultValue` so the placeholder is filled:
  `String(localized: "studyView.progress.learned", defaultValue: "\(known) of \(total) learned")`.
  Store the result in a `String` and render it with `Text(verbatim:)`; plain
  `Text(someString)` is not localized. Helper views that show copy take
  `LocalizedStringKey` (as in `CreateItemSheet`, `SectionHeader`,
  `SideEditorSection`) or a pre-localized `String` (`AppearanceEditor.subtitle`).
- Counts use plural variations keyed by name, not by format string:
  `LocalizedCounts.subjects/sets/cards` map to `shared.counts.subjects`,
  `shared.counts.sets`, `shared.counts.cards`, and `StudyView` uses
  `studyView.progress.cardsLeft`. Their values keep the `%lld` placeholder
  (counts format with `%lld`; `String` arguments use `%@`).
- If a translation does not appear, check that the key in the catalog matches
  the literal passed in Swift exactly, and mirror a `LocalizedStringKey` to
  confirm the key it resolves to.
- **All non-English translations are machine translated.** Nothing in the app
  says so, so keep new translations close to the English wording until they
  have been reviewed by native speakers.
- Localize picker options, help text, accessibility labels, and empty-state
  copy too. SF Symbol names, user-entered names, and the `Kōtoe` brand stay as
  they are.

## License

Kōtoe is released under the MIT License. The canonical text lives in the
`LICENSE` file at the repository root and is the only copy of the license
text — do not paste it into Swift code or the string catalog.

- The `LICENSE` file is registered explicitly in
  `Kōtoe.xcodeproj/project.pbxproj` (like `Localizable.xcstrings`) so it is
  copied into the app bundle as a resource. It is the only root file that
  needs a project entry.
- There is no in-app license screen. The bundled file is the only copy of
  the text; an About screen would read it at runtime and derive the name,
  copyright line, app version and full text from the file, so they cannot
  drift from it.

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
- New user-facing copy goes through `Localizable.xcstrings` with all five
  languages; see **Localization** before adding a string.
- Subject/set appearance is edited through `AppearanceEditor`; render icons with
  `model.style` and tint card/background surfaces with `style.tint`
  (`cardSurface(tint:)`, `AmbientBackground(tint:)`) instead of hardcoding
  `KotoeTheme.accent`.
- The toolbar add buttons (home view and subject view) stay black/white with
  `.tint(.primary)` on the `Button`. A toolbar button ignores
  `.foregroundStyle` on the label on iOS, so tint the button, not the label.
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
- The native macOS sheet action bar (created by a `.confirmationAction`
  toolbar item) does not pick up the tinted background. `FlashcardSetEditView`
  uses an in-content `safeAreaInset` footer with its Done button on macOS and
  keeps the native toolbar on iOS. On macOS the window toolbar is hidden
  (`.toolbarVisibility(.hidden, for: .windowToolbar)`) because the native
  titlebar draws its own solid material that cuts the ambient gradient; the
  screens show their title in the content instead, and `FlashcardEditorView`
  provides its own back button (`dismiss()` pops the pushed destination).
  Keep the footer inset inside the `ZStack` and avoid a `Divider` or opaque
  footer fill.
- Images render through `NSImage`/`UIImage` helpers, and drawings are rendered
  in light mode so ink matches the white canvas.
- PDFKit's `PDFView` is wrapped separately per platform in `PDFViewer.swift`.
  It is interactive (scrollable), so a PDF on a study card can swallow the
  tap-to-flip gesture; the study controls remain the reliable way to flip.
- `.fileImporter` URLs are security scoped. On macOS the app needs
  `com.apple.security.files.user-selected.read-only`, and imports must call
  `startAccessingSecurityScopedResource()` before reading and balance it with
  `stopAccessingSecurityScopedResource()`.

## Where to change what

- Add a screen field: extend the model, then the relevant form in
  `Views/Structure/SubjectView.swift` / `Views/FlashcardSetEditView.swift`.
- Change study behavior (queue, scoring, shuffling):
  `Views/Structure/StudyView.swift`.
- Change card rendering or add a content type: `FlashcardSideContentView.swift`
  plus the `FlashcardContentType` enum and the side editor's picker.
- Change how bulk imports are parsed (separator, escaping):
  `Import/TextCardImporter.swift`.
- Change the import sheet (paste, file, preview): `Views/CardImportView.swift`.
- Change which files a card side accepts and how they are detected:
  `Import/ImportedFile.swift` and the side editor in `FlashcardSetEditView.swift`.
- Change card media storage: `Control/Media/MediaStore.swift`; the side's
  file-based helpers live in `Models/FlashcardSide.swift`. PDF import and
  viewing go through `Views/Helper/PDFViewer.swift` and the side editor in
  `Views/FlashcardSetEditView.swift`.
- Change persistence/schema: `FlashApp.swift` schema list plus the models;
  remember CloudKit defaults and that local stores may need a migration.
- New subject/set flows and list styling: `ContentView.swift`,
  `Views/Structure/SubjectView.swift`.
- Change icon/color choices or the appearance UI: `Views/Theme.swift`
  (`subjectSymbols`, `setSymbols`, `palette`) and
  `Views/Helper/AppearanceEditor.swift`.
- Change UI copy or add a language: `Localizable.xcstrings`, plus
  `Control/LocalizedCounts.swift` for plural counts; see **Localization**.
- Change sync status, logging, or CloudKit diagnostics:
  `Control/Sync/CloudKitSyncMonitor.swift` and the footer in
  `ContentView.swift`; see **iCloud sync**.
- Change the license text: the `LICENSE` file at the repository root; see
  **License**.
- Change the public project page: `README.md` and the screenshots in
  `docs/images/`.

## Known gaps (safe next steps)

- No spaced-repetition scheduling: sessions are a simple re-queue, with no
  review intervals, due dates, or per-card history.
- No archive UI despite `isArchived` plumbing; no reordering of subjects/sets
  (only cards can be moved).
- Bulk import only takes text: pasted or a text file. There is no export, no
  Anki/CSV file import, no search, and no tags.
- Non-English UI strings are machine translated and have not been reviewed by
  native speakers. The app does not point this out to the user.
- Rich text is stored as RTF but edited and rendered as plain text.
- CloudKit sync failures are only logged and summarised in the library footer;
  there is no retry button, no `CKContainer.accountStatus` check, and the model
  container still calls `fatalError` when it cannot be created.
- Orphaned sets/cards (a `nil` parent left behind by a cascade delete on another
  device) have no UI and no repair pass, so they are invisible but still stored.
- Deleting a card locally calls `removeMediaFiles()` before
  `modelContext.delete`, but a cascade delete applied by another device leaves
  its iCloud Drive media file behind. There is no background sweep for
  unreferenced files yet.
- The push-notification entitlement and background mode are only there for
  SwiftData's CloudKit mirror; the app has no notification code of its own. No
  tests.

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
