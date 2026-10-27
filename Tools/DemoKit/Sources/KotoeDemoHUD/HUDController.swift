//
//  HUDController.swift
//  Kōtoe DemoKit
//
//  Owns the floating panel and supervises the demo worker process.
//

import AppKit
import SwiftUI

@MainActor
final class HUDController: NSObject, NSApplicationDelegate {

    static var shared: HUDController?

    private let options: HUDOptions
    private let model: HUDModel

    private var panel: NSPanel!
    private var scrim: NSWindow?
    private var process: Process?
    private var ticker: Timer?
    private var closeTimer: Timer?
    private var pendingOutput = ""
    private var errorLine: String?
    private var cancelledByUser = false
    private var finished = false

    init(options: HUDOptions) {
        self.options = options
        self.model = HUDModel(
            title: options.title,
            startsCompact: options.startsCompact
        )

        super.init()

        HUDController.shared = self
    }

    // MARK: - Lifecycle

    func start() {
        buildPanel()
        buildScrim()
        showPanel()
        startTicker()
        runCommand()
    }

    // MARK: - Panel

    private func buildPanel() {
        panel = NSPanel(
            contentRect: NSRect(
                x: 0,
                y: 0,
                width: HUDMetrics.width,
                height: HUDMetrics.height(for: model)
            ),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        refreshContent()
    }

    private func buildScrim() {
        guard let screen = NSScreen.main else { return }

        let scrim = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        scrim.level = NSWindow.Level(
            rawValue: NSWindow.Level.floating.rawValue - 1
        )
        scrim.backgroundColor = NSColor.black.withAlphaComponent(0.10)
        scrim.isOpaque = false
        scrim.hasShadow = false
        scrim.ignoresMouseEvents = true
        scrim.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        scrim.isReleasedWhenClosed = false

        self.scrim = scrim
    }

    private func showPanel() {
        if !model.isCompact {
            scrim?.orderFrontRegardless()
        }

        panel.orderFrontRegardless()
        positionPanel()
    }

    /// Keeps the card centered under the menu bar when it changes size.
    private func positionPanel() {
        guard let screen = NSScreen.main else { return }

        let size = panel.frame.size
        let visible = screen.visibleFrame
        let origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.maxY - size.height - HUDMetrics.screenMargin
        )

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func refreshContent() {
        let width = model.isCompact
            ? HUDMetrics.pillWidth
            : HUDMetrics.width
        let height = model.isCompact
            ? HUDMetrics.pillHeight
            : HUDMetrics.height(for: model)

        let content: AnyView

        if model.isCompact {
            content = AnyView(
                HUDPill(
                    model: model,
                    onExpand: { [weak self] in self?.setCompact(false) },
                    onStop: { [weak self] in self?.stop() }
                )
            )
        } else {
            content = AnyView(
                HUDCard(
                    model: model,
                    onHide: { [weak self] in self?.setCompact(true) },
                    onStop: { [weak self] in self?.stop() },
                    onOpen: { [weak self] in self?.openResult() },
                    onClose: { [weak self] in self?.close() }
                )
            )
        }

        let host = NSHostingView(rootView: content)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        host.autoresizingMask = [.width, .height]

        panel.contentView = host
        panel.setContentSize(NSSize(width: width, height: height))
        positionPanel()
    }

    private func setCompact(_ compact: Bool) {
        guard model.isCompact != compact else { return }

        model.isCompact = compact
        refreshContent()

        if compact {
            scrim?.orderOut(nil)
        } else {
            scrim?.orderFrontRegardless()
            panel.orderFrontRegardless()
        }
    }

    // MARK: - Clock

    private func startTicker() {
        let timer = Timer(timeInterval: 0.2, repeats: true) { _ in
            MainActor.assumeIsolated {
                self.model.now = Date()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    // MARK: - Command

    private func runCommand() {        let process = Process()
        process.executableURL = URL(fileURLWithPath: options.command[0])
        process.arguments = Array(options.command.dropFirst())
        process.currentDirectoryURL = URL(
            fileURLWithPath: options.workingDirectory,
            isDirectory: true
        )

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.relay(data)
        }

        stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.relay(data)
        }

        process.terminationHandler = { [weak self] process in
            Task { @MainActor in
                self?.commandFinished(
                    status: process.terminationStatus,
                    reason: process.terminationReason
                )
            }
        }

        do {
            try process.run()
            self.process = process
        } catch {
            fail("Could not start the demo: \(error.localizedDescription)")
        }
    }

    /// Echoes worker output so the caller still sees the render markers, and
    /// updates the panel from the marker lines.
    private nonisolated func relay(_ data: Data) {
        FileHandle.standardOutput.write(data)

        guard let text = String(data: data, encoding: .utf8) else { return }

        Task { @MainActor in
            self.consume(text)
        }
    }

    private func consume(_ text: String) {
        pendingOutput += text

        while let newline = pendingOutput.firstIndex(of: "\n") {
            let line = String(pendingOutput[..<newline])
            pendingOutput = String(pendingOutput[pendingOutput.index(after: newline)...])
            handle(line)
        }
    }

    private func handle(_ line: String) {
        let parts = line.split(
            separator: "=",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        guard parts.count == 2 else { return }

        let key = String(parts[0])
        let value = String(parts[1])

        switch key {
        case "DEMO_PHASE":
            if value == "rendering" {
                model.status = .running
            }

        case "DEMO_PLAN":
            if let total = Int(value) {
                model.total = total
            }

        case "DEMO_RENDERING":
            model.currentScene = value
            model.status = .running

        case "DEMO_PROGRESS":
            let counts = value.split(separator: "/")
            if counts.count == 2 {
                model.completed = Int(counts[0]) ?? model.completed
                model.total = Int(counts[1]) ?? model.total
            }

        case "DEMO_IMAGE":
            model.images.append(value)

        case "DEMO_ERROR":
            errorLine = value

        case "DEMO_DONE":
            break

        case "DEMO_FINISHED":
            // The image was written; nothing else to update. The progress
            // marker from the same run already recorded it.
            break

        default:
            break
        }
    }

    // MARK: - Finishing

    private func commandFinished(
        status: Int32,
        reason: Process.TerminationReason
    ) {
        guard !finished else { return }

        if cancelledByUser {
            finish(as: .cancelled, exitCode: 130, closeAfter: 1.5)
            return
        }

        if status == 0, !model.images.isEmpty {
            model.currentScene = nil
            finish(as: .finished, exitCode: 0, closeAfter: 3)

            if options.opensResult {
                openResult()
            }
            return
        }

        if status == 0 {
            fail("The demo finished without writing an image.")
        } else {
            fail(errorLine ?? "The demo stopped with exit code \(status).")
        }
    }

    private func fail(_ message: String) {
        finish(as: .failed(message), exitCode: 1, closeAfter: 8)
    }

    private func finish(
        as status: HUDModel.Status,
        exitCode: Int32,
        closeAfter seconds: TimeInterval
    ) {
        finished = true
        model.status = status
        model.finishedAt = Date()
        ticker?.invalidate()
        ticker = nil

        if model.isCompact, status != .finished {
            model.isCompact = false
        }

        refreshContent()

        let timer = Timer(timeInterval: seconds, repeats: false) { _ in
            MainActor.assumeIsolated {
                self.exit(code: exitCode)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        closeTimer = timer
    }

    // MARK: - Actions

    private func stop() {
        cancelledByUser = true
        model.status = .cancelled
        model.finishedAt = Date()

        if let process, process.isRunning {
            process.terminate()
        }

        // The renderer can be inside AppKit's run loop; make sure it really
        // ends instead of leaving the panel waiting forever.
        let deadline = Date(timeIntervalSinceNow: 2)
        while let process, process.isRunning, Date() < deadline {
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
        }

        if let process, process.isRunning {
            kill(process.processIdentifier, SIGKILL)
        }

        finish(as: .cancelled, exitCode: 130, closeAfter: 1.5)
    }

    private func openResult() {
        guard let path = model.images.last else { return }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func close() {
        exit(code: finishedExitCode)
    }

    private func exit(code: Int32) {
        closeTimer?.invalidate()
        closeTimer = nil
        ticker?.invalidate()
        ticker = nil

        if let process, process.isRunning {
            process.terminate()
        }

        scrim?.orderOut(nil)
        panel.orderOut(nil)

        Darwin.exit(code)
    }
}

private extension HUDController {

    /// Exit with the status of the finished run; 130 for a user stop, 1 for a
    /// failure, 0 for success.
    var finishedExitCode: Int32 {
        if case .failed = model.status { return 1 }
        if case .cancelled = model.status { return 130 }
        return 0
    }
}

extension HUDController {

    /// Never leave a renderer running when the terminal or the caller closes
    /// the panel.
    func applicationWillTerminate(_ notification: NSNotification) {
        if let process, process.isRunning {
            process.terminate()
        }
    }
}
