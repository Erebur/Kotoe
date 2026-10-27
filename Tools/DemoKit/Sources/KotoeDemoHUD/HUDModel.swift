//
//  HUDModel.swift
//  Kōtoe DemoKit
//
//  State behind the demo panel. The panel is a development tool, so its copy
//  is plain English instead of going through the app's string catalog.
//

import Foundation
import Observation

@MainActor
@Observable
final class HUDModel {

    enum Status: Equatable {
        /// The renderer is being compiled.
        case preparing
        /// Scenes are being rendered.
        case running
        /// Every scene has an image.
        case finished
        case failed(String)
        case cancelled
    }

    let title: String

    var status: Status = .preparing
    var completed = 0
    var total = 0
    var currentScene: String?
    var images: [String] = []
    var isCompact: Bool
    var now = Date()

    let startedAt = Date()
    var finishedAt: Date?

    init(title: String, startsCompact: Bool) {
        self.title = title
        self.isCompact = startsCompact
    }

    // MARK: - Progress

    /// 0...1, used for the bar. Preparing has no measurable progress.
    var progress: Double {
        guard total > 0 else { return 0 }
        return min(Double(completed) / Double(total), 1)
    }

    var elapsed: TimeInterval {
        (finishedAt ?? now).timeIntervalSince(startedAt)
    }

    /// Rough remaining time. It needs one finished scene to know how long a
    /// scene takes; before that it assumes the measured average of ~0.65 s.
    var remaining: TimeInterval? {
        switch status {
        case .preparing, .failed:
            return nil
        case .finished, .cancelled:
            return 0
        case .running:
            guard total > 0 else { return nil }

            let done = max(completed, 1)
            let perScene = max(elapsed / Double(done), 0.25)
            let left = max(total - completed, 0)
            return perScene * Double(left)
        }
    }

    var isBusy: Bool {
        status == .preparing || status == .running
    }

    var isPreparing: Bool {
        status == .preparing
    }

    var headline: String {
        switch status {
        case .preparing:
            return "Building the demo"
        case .running:
            if let currentScene {
                return "Rendering \(currentScene)"
            }
            return "Rendering"
        case .finished:
            return "Demo ready"
        case .failed:
            return "Demo failed"
        case .cancelled:
            return "Demo stopped"
        }
    }

    var detail: String {
        switch status {
        case .preparing:
            return "First run compiles the app; later runs take a second."
        case .running:
            let counts = "\(completed) of \(total) screens"
            guard let remaining else { return counts }
            if remaining < 1 {
                return "\(counts) · almost done"
            }
            return "\(counts) · " + "\(Int(remaining.rounded(.up)))s left"
        case .finished:
            return "\(images.count) screens in "
                + String(format: "%.1fs", elapsed)
        case .failed(let message):
            return message
        case .cancelled:
            return "Stopped by you. No image was written."
        }
    }

    /// Short text for the collapsed pill.
    var compactDetail: String {
        switch status {
        case .preparing:
            return "Preparing…"
        case .running:
            guard let remaining, remaining >= 1 else { return "Almost done" }
            return "\(Int(remaining.rounded(.up)))s left"
        case .finished:
            return "Ready"
        case .failed:
            return "Failed"
        case .cancelled:
            return "Stopped"
        }
    }
}
