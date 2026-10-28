# Kōtoe DemoKit

A development-only helper that renders Kōtoe screens headlessly and shows a
small floating panel while it works. It compiles the app's own SwiftUI views
into a command-line tool, so a demo matches the working tree without launching
the app, booting a simulator, or touching the real library.

```sh
Tools/demo library              # one screen, panel included
Tools/demo library study-card   # a batch, one app activation
Tools/demo --list               # every scene and its default size
```

Images land in `.demo/` unless `--out` or `--out-dir` says otherwise. The
command prints the usual `DEMO_*` markers, so the path of a rendered image is
available even when the panel is used.

## The panel

While a demo runs, a floating card sits under the menu bar:

- the screen being rendered, the number of finished screens, a progress bar,
  and the estimated time left;
- **Hide** collapses it into a small pill that keeps the progress ring;
- **Stop** ends the render immediately;
- when the images are done it shows a preview, **Open Image**, and closes
  itself after a few seconds.

The card is a non-activating panel above other windows, with a light dim over
the main screen. Clicks outside it keep working. Rendering is the only part
that takes focus: SwiftUI draws prominent buttons and tinted controls gray in
an inactive window, so the renderer briefly activates an invisible window and
gives focus back to the previously frontmost app when it is done. A batch of
scenes only takes focus once.

`--compact` starts collapsed; `--no-hud` skips the panel entirely, which is
what scripts and CI-like runs should use.

## Scenes

| Scene | Shows |
| --- | --- |
| `library` | Six sample subjects, seven sets, nineteen cards |
| `library-empty` | First-run library |
| `subject` | Subject detail with sets and notes |
| `set-editor` | Set editor with its cards |
| `card-editor` | The card editor for one card |
| `study-start` | Study session start screen |
| `study-card` | One study card face |
| `study-finished` | Finished session |
| `import` | Bulk import sheet |
| `appearance` | Icon and color editor |
| `sync-log` | CloudKit error log with resolved record items |

Every scene uses a fresh in-memory `ModelContainer` with
`cloudKitDatabase: .none`, so a demo can never read or write the real store,
sync anything, or leave media behind. The sample library lives in
`DemoData.swift`.

Options mirror the parts of the app worth varying: `--size WxH`, `--scale N`
(1–4, default 2), `--appearance light|dark|system`, `--locale de`, and
`--settle SECONDS` (how long the first window gets before the capture).

## How it works

```
Tools/demo                      arg parsing, build cache, worker/panel split
Tools/DemoKit/
  Package.swift                 SwiftPM package, two executables
  Package.resolved              pinned SwiftMath / HighlighterSwift versions
  Sources/KotoeDemo/
    Kotoe -> ../../../../Kotoe  the app's sources, compiled into the tool
    DemoCLI.swift               entry point, markers, app lifecycle
    DemoRenderer.swift          offscreen capture
    DemoScenes.swift            scene registry
    DemoData.swift              sample library and sync failures
    DemoOptions.swift           command-line options
  Sources/KotoeDemoHUD/
    HUDMain.swift               panel app entry point
    HUDController.swift         panel windows and child process
    HUDView.swift               card and pill
    HUDModel.swift              progress, elapsed time, ETA
```

- SwiftPM compiles `Kotoe/` through a symlink, so any new app file is picked
  up automatically and a demo can never drift from the sources. `FlashApp.swift`
  is excluded because the demo tool provides its own `@main`. The package
  declares the same SwiftMath and HighlighterSwift dependencies as the app,
  because the compiled sources import them.
- `ImageRenderer` draws `ScrollView` content blank, so the renderer puts each
  view in a real `NSHostingView` inside a transparent window and captures its
  backing store with `cacheDisplay(in:to:)`. The window sits in the corner of
  the main screen because only on-screen windows can become key, and it is
  transparent, so nothing is visible.
- The window is a non-activating `NSPanel`. Making it key is what gives the
  capture the active look. `NSApp.activate` is deliberately not called: from a
  background process macOS refuses it, and it also prevents the panel from
  becoming key.
- `Tools/demo` skips `swift build` when the product is newer than its sources.
  The first run compiles for about 20 seconds; after that startup is instant
  and each scene takes roughly 0.5–1.5 seconds.
- The string catalog is compiled with `xcstringstool` next to the executable so
  `Bundle.main` finds `.lproj` folders; no app bundle is needed.
- The panel supervises `Tools/demo --worker …` as a child process and reads
  `DEMO_PHASE`, `DEMO_PLAN`, `DEMO_RENDERING`, `DEMO_PROGRESS`, `DEMO_IMAGE`,
  `DEMO_FINISHED`, `DEMO_ERROR`, and `DEMO_DONE` lines. Any other line is
  echoed unchanged.

## Adding a scene

1. Add a `DemoScene` to `DemoScenes.all` with an id, a title, a default size,
   and a closure that builds the view.
2. Build model-backed screens from `DemoData.library()` and pass its
   `container` through `wrap(_:container:)`; sheet-sized screens are wrapped
   without a container.
3. Render it and look at the image before committing.

Do not change app behavior to make a scene easier. If a screen needs state the
demo cannot reach, wrap it in a small demo-only view like
`DemoAppearanceView`.

## Limits

- The tool renders the macOS layout only. iOS-specific presentation
  (`fullScreenCover`, detents) is not exercised; use the simulator flow in
  `AGENTS.md` for that.
- A scene is a still image. Gestures, animation frames, and typing states are
  not captured; build a dedicated scene when a change needs one of those.
- Rendering needs a logged-in graphical session. It does not work over SSH.
