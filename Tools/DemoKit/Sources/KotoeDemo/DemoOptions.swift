//
//  DemoOptions.swift
//  Kōtoe DemoKit
//
//  Command-line options for the headless renderer.
//

import CoreGraphics
import Foundation

enum DemoCommand {
    case render
    case list
    case help
}

enum DemoAppearance: String {
    case light
    case dark
    case system

    var colorScheme: DemoColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

/// Mirrors SwiftUI's `ColorScheme` without making the option parser depend on
/// SwiftUI.
enum DemoColorScheme: Equatable {
    case light
    case dark
}

struct DemoOptions {
    var command: DemoCommand = .render
    var sceneIDs: [String] = []
    var outputPath: String?
    var outputDirectory: String?
    var width: Int?
    var height: Int?
    var scale = 2
    var appearance: DemoAppearance = .light
    var locale: String?
    var settle: Double = 0.6
    var json = false

    var size: CGSize? {
        guard let width, let height else { return nil }
        return CGSize(width: width, height: height)
    }

    // MARK: - Parsing

    static func parse(_ arguments: [String]) throws -> DemoOptions {
        var options = DemoOptions()
        var index = 0

        func nextValue(for flag: String) throws -> String {
            index += 1
            guard index < arguments.count else {
                throw DemoUsageError.missingValue(flag)
            }
            return arguments[index]
        }

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "render":
                options.command = .render

            case "list", "--list":
                options.command = .list

            case "help", "--help", "-h":
                options.command = .help

            case "--scene":
                options.sceneIDs.append(try nextValue(for: argument))

            case "--out", "-o":
                options.outputPath = try nextValue(for: argument)

            case "--out-dir":
                options.outputDirectory = try nextValue(for: argument)

            case "--size":
                let value = try nextValue(for: argument)
                let parts = value
                    .replacingOccurrences(of: "×", with: "x")
                    .split(separator: "x", omittingEmptySubsequences: true)
                guard
                    parts.count == 2,
                    let width = Int(parts[0]),
                    let height = Int(parts[1]),
                    width > 0,
                    height > 0
                else {
                    throw DemoUsageError.invalidValue(argument, value)
                }
                options.width = width
                options.height = height

            case "--width":
                let value = try nextValue(for: argument)
                guard let width = Int(value), width > 0 else {
                    throw DemoUsageError.invalidValue(argument, value)
                }
                options.width = width

            case "--height":
                let value = try nextValue(for: argument)
                guard let height = Int(value), height > 0 else {
                    throw DemoUsageError.invalidValue(argument, value)
                }
                options.height = height

            case "--scale":
                let value = try nextValue(for: argument)
                guard let scale = Int(value), (1...4).contains(scale) else {
                    throw DemoUsageError.invalidValue(argument, value)
                }
                options.scale = scale

            case "--appearance":
                let value = try nextValue(for: argument)
                guard let appearance = DemoAppearance(rawValue: value) else {
                    throw DemoUsageError.invalidValue(argument, value)
                }
                options.appearance = appearance

            case "--locale":
                options.locale = try nextValue(for: argument)

            case "--settle":
                let value = try nextValue(for: argument)
                guard
                    let settle = Double(value),
                    (0...10).contains(settle)
                else {
                    throw DemoUsageError.invalidValue(argument, value)
                }
                options.settle = settle

            case "--json":
                options.json = true

            default:
                guard !argument.hasPrefix("-") else {
                    throw DemoUsageError.unknownOption(argument)
                }
                options.sceneIDs.append(argument)
            }

            index += 1
        }

        if options.sceneIDs.isEmpty {
            options.sceneIDs = ["library"]
        }

        return options
    }

    static let usage = """
    Usage: Tools/demo [scene ...] [options]

    Renders one or more Kōtoe screens headlessly and shows a progress panel
    while it works.

    Scenes:
      library          Library with six sample subjects
      library-empty    Empty library / first-run state
      subject          Subject detail with sets and notes
      set-editor       Set editor with cards
      card-editor      Card editor for one card
      study-start      Study session start screen
      study-card       Study card face
      study-finished   Finished study session
      import           Bulk card import sheet
      appearance       Icon and color editor
      sync-log         CloudKit error log

    Options:
      --out PATH          Write a single scene to PATH
      --out-dir DIR       Directory for several scenes (default: .)
      --size WxH          Override the scene's default size
      --scale N           Pixel scale, 1...4 (default 2)
      --appearance MODE   light (default), dark, or system
      --locale CODE       Force a language, e.g. en, de, es, fr, ja
      --settle SECONDS    Wait before the first capture (default 0.6)
      --json              Print the scene list as JSON (with --list)

    Wrapper options:
      --no-hud            Render without the progress panel
      --compact           Start the panel collapsed
      --open              Open the rendered image when done

    The wrapper prints the image paths, so a demo can be shown with
    `Tools/demo library --open`.
    """
}

enum DemoUsageError: LocalizedError {
    case missingValue(String)
    case invalidValue(String, String)
    case unknownOption(String)

    var errorDescription: String? {
        switch self {
        case .missingValue(let flag):
            return "\(flag) needs a value"
        case .invalidValue(let flag, let value):
            return "\(flag) does not accept \(value)"
        case .unknownOption(let flag):
            return "unknown option \(flag)"
        }
    }
}
