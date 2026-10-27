//
//  HUDMain.swift
//  Kōtoe DemoKit
//
//  A small floating panel that shows what the demo helper is doing, how far
//  along it is, and how long it will take. It supervises the renderer and can
//  stop it at any time.
//

import AppKit

@main
@MainActor
struct KotoeDemoHUDMain {

    static func main() {
        let options: HUDOptions
        do {
            options = try HUDOptions.parse(
                Array(CommandLine.arguments.dropFirst())
            )
        } catch {
            FileHandle.standardError.write(
                Data("KotoeDemoHUD: \(error.localizedDescription)\n".utf8)
            )
            exit(2)
        }

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)

        let controller = HUDController(options: options)
        controller.start()

        app.run()
    }
}

// MARK: - Options

struct HUDOptions {

    /// The helper script with its arguments; the script builds and runs the
    /// renderer. The HUD only supervises it and parses its progress markers.
    var command: [String] = []
    var title = "Kōtoe demo"
    var startsCompact = false
    var opensResult = false
    var workingDirectory = FileManager.default.currentDirectoryPath

    static func parse(_ arguments: [String]) throws -> HUDOptions {
        var options = HUDOptions()
        var index = 0
        var commandStarted = false

        while index < arguments.count {
            let argument = arguments[index]

            if commandStarted {
                options.command.append(argument)
                index += 1
                continue
            }

            func value(_ flag: String) throws -> String {
                index += 1
                guard index < arguments.count else {
                    throw HUDOptionError.missingValue(flag)
                }
                return arguments[index]
            }

            switch argument {
            case "--":
                commandStarted = true

            case "--cwd":
                options.workingDirectory = try value(argument)

            case "--title":
                options.title = try value(argument)

            case "--compact":
                options.startsCompact = true

            case "--open":
                options.opensResult = true

            default:
                throw HUDOptionError.unknownOption(argument)
            }

            index += 1
        }

        guard !options.command.isEmpty else {
            throw HUDOptionError.missingCommand
        }

        return options
    }
}

enum HUDOptionError: LocalizedError {
    case missingValue(String)
    case unknownOption(String)
    case missingCommand

    var errorDescription: String? {
        switch self {
        case .missingValue(let flag):
            return "\(flag) needs a value"
        case .unknownOption(let flag):
            return "unknown option \(flag)"
        case .missingCommand:
            return "no command to run (pass it after --)"
        }
    }
}
