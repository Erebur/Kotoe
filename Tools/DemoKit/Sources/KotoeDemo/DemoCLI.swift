//
//  DemoCLI.swift
//  Kōtoe DemoKit
//
//  Entry point for the headless demo renderer.
//

import AppKit
import Foundation

@main
@MainActor
struct KotoeDemoMain {

    static func main() {
        do {
            let options = try DemoOptions.parse(
                Array(CommandLine.arguments.dropFirst())
            )

            switch options.command {
            case .help:
                print(DemoOptions.usage)

            case .list:
                try printScenes(json: options.json)

            case .render:
                try runRenderer(options)
            }
        } catch {
            writeError(error.localizedDescription)
            exit(1)
        }
    }

    // MARK: - Render

    private static func runRenderer(_ options: DemoOptions) throws {
        let scenes = try options.sceneIDs.map { id -> DemoScene in
            guard let scene = DemoScenes.scene(id: id) else {
                let ids = DemoScenes.all.map(\.id).joined(separator: ", ")
                throw DemoCLIError.unknownScene(id, ids)
            }
            return scene
        }

        let outputs = try outputURLs(for: options, scenes: scenes)

        if let locale = options.locale {
            UserDefaults.standard.set([locale], forKey: "AppleLanguages")
            UserDefaults.standard.set(locale, forKey: "AppleLocale")
        }

        print("DEMO_PLAN=\(scenes.count)")

        let runner = DemoRunner(
            scenes: scenes,
            outputs: outputs,
            options: options
        )

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = options.appearance.nsAppearance
        app.delegate = runner

        // A launched app (not the bare main function) is what makes AppKit
        // accept the activation, which SwiftUI needs to draw tinted controls.
        app.run()
    }

    private static func outputURLs(
        for options: DemoOptions,
        scenes: [DemoScene]
    ) throws -> [URL] {
        let base = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )

        if scenes.count == 1, let outputPath = options.outputPath {
            return [
                URL(fileURLWithPath: outputPath, relativeTo: base)
                    .standardizedFileURL
            ]
        }

        guard options.outputPath == nil else {
            throw DemoCLIError.outputNeedsSingleScene
        }

        let directory = options.outputDirectory ?? "."
        return scenes.map { scene in
            URL(
                fileURLWithPath: directory,
                isDirectory: true,
                relativeTo: base
            )
            .appendingPathComponent("\(scene.id).png")
            .standardizedFileURL
        }
    }

    // MARK: - List

    private static func printScenes(json: Bool) throws {
        let scenes = DemoScenes.all

        if json {
            let rows: [[String: Any]] = scenes.map { scene in
                [
                    "id": scene.id,
                    "title": scene.title,
                    "width": Int(scene.defaultSize.width),
                    "height": Int(scene.defaultSize.height),
                ]
            }
            let data = try JSONSerialization.data(
                withJSONObject: rows,
                options: [.prettyPrinted, .sortedKeys]
            )
            print(String(decoding: data, as: UTF8.self))
            return
        }

        for scene in scenes {
            let id = scene.id.padding(
                toLength: 16,
                withPad: " ",
                startingAt: 0
            )
            let size = "\(Int(scene.defaultSize.width))×"
                + "\(Int(scene.defaultSize.height))"
            print("\(id)\(size)\t\(scene.title)")
        }
    }

    // MARK: - Errors

    private static func writeError(_ message: String) {
        let line = "DEMO_ERROR=\(message)\n"
        FileHandle.standardError.write(Data(line.utf8))
    }
}

// MARK: - Runner

/// App delegate that performs the render once AppKit has finished launching,
/// so the helper app is a real app when it asks for focus.
@MainActor
private final class DemoRunner: NSObject, NSApplicationDelegate {

    private let scenes: [DemoScene]
    private let outputs: [URL]
    private let options: DemoOptions

    init(
        scenes: [DemoScene],
        outputs: [URL],
        options: DemoOptions
    ) {
        self.scenes = scenes
        self.outputs = outputs
        self.options = options
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try render()
            print("DEMO_DONE")
            exit(0)
        } catch {
            let line = "DEMO_ERROR=\(error.localizedDescription)\n"
            FileHandle.standardError.write(Data(line.utf8))
            exit(1)
        }
    }

    private func render() throws {
        let jobs = zip(scenes, outputs).map { scene, output in
            DemoRenderJob(
                id: scene.id,
                title: scene.title,
                view: scene.makeView(),
                size: options.size ?? scene.defaultSize,
                output: output
            )
        }

        let total = jobs.count
        var completed = 0

        try DemoRenderer.render(
            jobs: jobs,
            scale: options.scale,
            settle: options.settle,
            appearance: options.appearance,
            locale: options.locale
        ) { job in
            print("DEMO_RENDERING=\(job.title)")
            fflush(stdout)
        } onJob: { result in
            completed += 1

            print("DEMO_FINISHED=\(result.id)")
            print("DEMO_IMAGE=\(result.url.path)")
            print("DEMO_SCENE=\(result.id)")
            print("DEMO_WIDTH=\(Int(result.size.width))")
            print("DEMO_HEIGHT=\(Int(result.size.height))")
            print(
                "DEMO_PIXELS="
                    + "\(Int(result.pixelSize.width))x"
                    + "\(Int(result.pixelSize.height))"
            )
            print(String(format: "DEMO_SECONDS=%.2f", result.seconds))
            print("DEMO_PROGRESS=\(completed)/\(total)")
            fflush(stdout)
        }
    }
}

enum DemoCLIError: LocalizedError {
    case unknownScene(String, String)
    case outputNeedsSingleScene

    var errorDescription: String? {
        switch self {
        case .unknownScene(let id, let available):
            return "unknown scene '\(id)'. Available scenes: \(available)"
        case .outputNeedsSingleScene:
            return "--out needs exactly one scene; use --out-dir for many"
        }
    }
}
