//
//  DemoRenderer.swift
//  Kōtoe DemoKit
//
//  Renders SwiftUI views into PNGs without showing an app window.
//

import AppKit
import SwiftUI

/// One screen to capture.
struct DemoRenderJob {
    let id: String
    let title: String
    let view: AnyView
    let size: CGSize
    let output: URL
}

struct DemoRenderResult {
    let id: String
    let url: URL
    let size: CGSize
    let pixelSize: CGSize
    let seconds: TimeInterval
}

enum DemoRenderError: LocalizedError {
    case noImage
    case noPNG
    case writeFailed(Error)
    case invalidSize

    var errorDescription: String? {
        switch self {
        case .noImage:
            return "The demo view did not produce an image"
        case .noPNG:
            return "The demo image could not be encoded as PNG"
        case .writeFailed(let error):
            return "The demo image could not be written: \(error)"
        case .invalidSize:
            return "The demo size must be positive"
        }
    }
}

/// Hosts each view in a real, fully transparent AppKit window, lets SwiftUI
/// lay it out, and captures the window's backing store.
///
/// `ImageRenderer` skips `ScrollView` content, so the view has to live in a
/// real hosting view. The window also has to be key and the app active for
/// SwiftUI to draw prominent buttons and tinted controls the way they look
/// while the user works with the app; an inactive window renders them gray.
/// The window is invisible and offscreen, and focus returns to the previously
/// frontmost app as soon as the captures are done.
@MainActor
enum DemoRenderer {

    /// Renders every job in order, activating the helper app once so a
    /// multi-scene demo only takes focus for a single short moment.
    static func render(
        jobs: [DemoRenderJob],
        scale: Int,
        settle: Double,
        appearance: DemoAppearance,
        locale: String?,
        onJobStart: (DemoRenderJob) -> Void = { _ in },
        onJob: (DemoRenderResult) -> Void
    ) throws {
        guard !jobs.isEmpty else { return }
        for job in jobs where job.size.width <= 0 || job.size.height <= 0 {
            throw DemoRenderError.invalidSize
        }

        let previousApp = NSWorkspace.shared.frontmostApplication
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.appearance = appearance.nsAppearance

        defer {
            NSApplication.shared.hide(nil)
            restoreFocus(to: previousApp)
        }

        for (index, job) in jobs.enumerated() {
            let started = Date()
            onJobStart(job)

            let host = NSHostingView(rootView: rootView(job, appearance, locale))
            host.frame = NSRect(origin: .zero, size: job.size)
            host.wantsLayer = true
            host.layer?.contentsScale = CGFloat(scale)
            host.appearance = appearance.nsAppearance

            // A nonactivating panel can turn key without pulling the app to
            // the front of the window stack; the title bar sits outside the
            // captured content view and the whole panel is transparent.
            let window = NSPanel(
                contentRect: host.frame,
                styleMask: [.nonactivatingPanel, .titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.contentView = host
            window.isReleasedWhenClosed = false
            window.isFloatingPanel = true
            window.becomesKeyOnlyIfNeeded = false
            window.hidesOnDeactivate = false
            window.alphaValue = 0
            window.backgroundColor = .windowBackgroundColor
            window.appearance = appearance.nsAppearance
            window.collectionBehavior = [.canJoinAllSpaces, .stationary]

            // A window only turns key while it sits on a screen, so place it
            // in the corner of the main screen. It is fully transparent.
            let visibleFrame = NSScreen.main?.visibleFrame ?? .zero
            window.setFrameOrigin(
                NSPoint(x: visibleFrame.minX, y: visibleFrame.minY)
            )
            window.orderFrontRegardless()

            defer {
                window.orderOut(nil)
                window.close()
            }

            // The first window also has to settle SwiftData's queries and the
            // layout pass; later windows reuse the already built store.
            pump(seconds: index == 0 ? max(settle, 0.15) : 0.2)

            // An accessory app can only be activated once it owns a window,
            // and the activation itself is asynchronous.
            makeActive(window)
            pump(seconds: 0.1)

            host.layoutSubtreeIfNeeded()
            host.needsDisplay = true
            host.displayIfNeeded()
            pump(seconds: 0.05)

            let result = try capture(
                host: host,
                job: job,
                scale: scale,
                started: started
            )
            onJob(result)
        }
    }

    // MARK: - Capture

    private static func capture(
        host: NSHostingView<AnyView>,
        job: DemoRenderJob,
        scale: Int,
        started: Date
    ) throws -> DemoRenderResult {
        let pixelWidth = Int(job.size.width) * scale
        let pixelHeight = Int(job.size.height) * scale

        guard
            let representation = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: pixelWidth,
                pixelsHigh: pixelHeight,
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: 0,
                bitsPerPixel: 0
            )
        else {
            throw DemoRenderError.noImage
        }

        representation.size = job.size
        host.cacheDisplay(in: host.bounds, to: representation)

        guard
            let png = representation.representation(
                using: .png,
                properties: [:]
            )
        else {
            throw DemoRenderError.noPNG
        }

        do {
            try FileManager.default.createDirectory(
                at: job.output.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try png.write(to: job.output, options: .atomic)
        } catch {
            throw DemoRenderError.writeFailed(error)
        }

        return DemoRenderResult(
            id: job.id,
            url: job.output,
            size: job.size,
            pixelSize: CGSize(width: pixelWidth, height: pixelHeight),
            seconds: Date().timeIntervalSince(started)
        )
    }

    private static func rootView(
        _ job: DemoRenderJob,
        _ appearance: DemoAppearance,
        _ locale: String?
    ) -> AnyView {
        var root = job.view

        if let locale {
            root = AnyView(
                root.environment(\.locale, Locale(identifier: locale))
            )
        }

        if let scheme = appearance.colorScheme {
            root = AnyView(
                root.environment(
                    \.colorScheme,
                    scheme == .light ? .light : .dark
                )
            )
        }

        return AnyView(
            root.frame(width: job.size.width, height: job.size.height)
        )
    }

    // MARK: - Run Loop

    /// Activation is asynchronous and an accessory app can refuse it while it
    /// is still launching, so retry for a moment before giving up. The key
    /// panel is what brings the app forward; `NSApp.activate` is not used
    /// because macOS refuses it from a background process.
    private static func makeActive(_ window: NSPanel) {
        let deadline = Date(timeIntervalSinceNow: 1)

        repeat {
            window.makeKeyAndOrderFront(nil)
            window.makeKey()
            if NSApplication.shared.isActive, window.isKeyWindow { return }
            pump(seconds: 0.05)
        } while Date() < deadline
    }

    /// SwiftData queries and SwiftUI layout run on the main run loop, so the
    /// offscreen window needs a few turns before it can be captured.
    private static func pump(seconds: TimeInterval) {
        RunLoop.main.run(until: Date(timeIntervalSinceNow: seconds))
    }

    /// Hiding the helper app hands focus back to whatever the user was using
    /// before the demo started.
    private static func restoreFocus(to previousApp: NSRunningApplication?) {
        guard
            let previousApp,
            previousApp.processIdentifier
                != ProcessInfo.processInfo.processIdentifier
        else {
            return
        }

        pump(seconds: 0.15)

        if !previousApp.isActive {
            previousApp.activate()
        }
    }
}

// MARK: - Appearance

extension DemoAppearance {

    var nsAppearance: NSAppearance? {
        switch self {
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        case .system:
            return nil
        }
    }
}
