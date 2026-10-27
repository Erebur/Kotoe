//
//  HUDView.swift
//  Kōtoe DemoKit
//
//  The visible part of the demo helper: a floating status card and its
//  collapsed pill.
//

import AppKit
import SwiftUI

private let demoAccent = Color(red: 0.851, green: 0.408, blue: 0.290)
private let demoSuccess = Color(red: 0.235, green: 0.522, blue: 0.404)

// MARK: - Card

struct HUDCard: View {

    let model: HUDModel
    let onHide: () -> Void
    let onStop: () -> Void
    let onOpen: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            progress

            if case .finished = model.status {
                preview
                actions
            }

            if case .failed = model.status {
                actions
            }
        }
        .padding(16)
        .frame(width: HUDMetrics.width, height: HUDMetrics.height(for: model))
        .background(.thickMaterial, in: shape)
        .overlay(
            shape.strokeBorder(.white.opacity(0.14), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.22), radius: 18, y: 8)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 11) {
            statusIcon

            VStack(alignment: .leading, spacing: 3) {
                Text(model.title.uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .tracking(1.3)
                    .foregroundStyle(demoAccent)

                Text(model.headline)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            if model.isBusy {
                iconButton("chevron.down", help: "Hide", action: onHide)
                iconButton("stop.fill", help: "Stop the demo", action: onStop)
            } else {
                iconButton("xmark", help: "Close", action: onClose)
            }
        }
    }

    private var statusIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [demoAccent, demoAccent.opacity(0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 34, height: 34)

            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
    }

    private var symbol: String {
        switch model.status {
        case .preparing, .running:
            return "camera.viewfinder"
        case .finished:
            return "checkmark"
        case .failed:
            return "exclamationmark"
        case .cancelled:
            return "stop.fill"
        }
    }

    // MARK: Progress

    private var progress: some View {
        VStack(alignment: .leading, spacing: 6) {
            bar
            detail
        }
    }

    private var bar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.primary.opacity(0.1))

                Capsule()
                    .fill(tint)
                    .frame(
                        width: barWidth(in: proxy.size.width),
                        height: proxy.size.height
                    )
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.25), value: model.progress)
    }

    private func barWidth(in width: CGFloat) -> CGFloat {
        guard !model.isPreparing else { return width * 0.18 }
        return max(width * model.progress, model.progress > 0 ? 6 : 0)
    }

    private var tint: Color {
        switch model.status {
        case .finished:
            return demoSuccess
        case .failed:
            return Color(red: 0.85, green: 0.32, blue: 0.28)
        default:
            return demoAccent
        }
    }

    private var detail: some View {
        HStack(spacing: 6) {
            Text(model.detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            if model.isBusy, !model.isPreparing {
                Text(verbatim: "\(Int((model.progress * 100).rounded()))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Finished

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.06))

            if let image = previewImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .padding(4)
            }
        }
        .frame(height: HUDMetrics.previewHeight)
    }

    private var previewImage: NSImage? {
        guard let path = model.images.last else { return nil }
        return NSImage(contentsOfFile: path)
    }

    private var actions: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                Text("Close")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(.primary.opacity(0.08), in: Capsule())
            }
            .buttonStyle(.plain)

            if case .finished = model.status {
                Button(action: onOpen) {
                    Text("Open Image")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(demoAccent, in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: Buttons

    private func iconButton(
        _ name: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: name)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(.primary.opacity(0.08), in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Pill

struct HUDPill: View {

    let model: HUDModel
    let onExpand: () -> Void
    let onStop: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            ring

            VStack(alignment: .leading, spacing: 1) {
                Text("Kōtoe demo")
                    .font(.system(size: 11, weight: .semibold))
                Text(model.compactDetail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if model.isBusy {
                Button(action: onStop) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 18, height: 18)
                        .background(.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
                .help("Stop the demo")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: HUDMetrics.pillWidth, height: HUDMetrics.pillHeight)
        .background(.thickMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
        .contentShape(Capsule())
        .onTapGesture(perform: onExpand)
    }

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.15), lineWidth: 2.5)

            Circle()
                .trim(
                    from: 0,
                    to: model.isPreparing ? 0.18 : model.progress
                )
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            if !model.isBusy {
                Image(systemName: "checkmark")
                    .font(.system(size: 6, weight: .black))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: 16, height: 16)
        .animation(.easeInOut(duration: 0.25), value: model.progress)
    }

    private var tint: Color {
        switch model.status {
        case .finished:
            return demoSuccess
        case .failed:
            return Color(red: 0.85, green: 0.32, blue: 0.28)
        default:
            return demoAccent
        }
    }
}

// MARK: - Metrics

enum HUDMetrics {

    static let width: CGFloat = 372
    static let pillWidth: CGFloat = 190
    static let pillHeight: CGFloat = 46
    static let previewHeight: CGFloat = 132
    static let screenMargin: CGFloat = 18

    @MainActor
    static func height(for model: HUDModel) -> CGFloat {
        switch model.status {
        case .finished:
            return 336
        case .failed:
            return 196
        case .preparing, .running, .cancelled:
            return 118
        }
    }
}

// MARK: - Preview

#Preview("Running") {
    let model = HUDModel(title: "Kōtoe demo", startsCompact: false)
    model.status = .running
    model.total = 4
    model.completed = 2
    model.currentScene = "Library"

    return HUDCard(
        model: model,
        onHide: {},
        onStop: {},
        onOpen: {},
        onClose: {}
    )
    .padding(40)
}
