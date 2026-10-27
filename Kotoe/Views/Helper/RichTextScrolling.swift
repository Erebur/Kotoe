//
//  RichTextScrolling.swift
//  Kōtoe
//
//  Created by Simon Weber on 27.10.26.
//
//  Scroll behaviour for the rich text field. `RichTextScrollView` keeps a
//  flick's momentum inside the field once its content reaches an edge, and
//  `SplitScrollSync` ties the editor and preview panes of the split display
//  mode to the same scroll position.
//

import Foundation

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Momentum scroll view (macOS)

#if os(macOS)

/// A scroll view that keeps the momentum of a scroll gesture inside itself
/// once its content reaches the top or bottom. AppKit otherwise chains the
/// leftover inertia to the enclosing scroll view, which throws the form the
/// field or pane sits in right after the fingers lift. Finger-driven scrolling
/// and content that fits still pass the gesture through, so the page scrolls
/// normally.
class RichTextScrollView: NSScrollView {

    override func scrollWheel(with event: NSEvent) {
        let delta = event.scrollingDeltaY
        guard delta != 0 else {
            super.scrollWheel(with: event)
            return
        }

        // Only the momentum tail is blocked; while the fingers are still on
        // the trackpad an exhausted field may chain to the enclosing view.
        if !event.momentumPhase.isEmpty,
           isAtVerticalEdge(towards: delta) {
            return
        }

        super.scrollWheel(with: event)
    }

    /// `delta` follows AppKit's convention: positive scrolls toward the top.
    private func isAtVerticalEdge(towards delta: CGFloat) -> Bool {
        guard let documentView else { return false }

        let visible = documentVisibleRect
        let contentHeight = documentView.frame.height
        let scrollableHeight =
            contentHeight + contentInsets.top + contentInsets.bottom
        guard scrollableHeight > visible.height + 0.5 else {
            // The text fits; the field has nothing to scroll.
            return false
        }

        if delta > 0 {
            return visible.minY <= -contentInsets.top + 0.5
        }
        // The bottom inset is room for the floating mode switch, so the
        // last line can scroll clear of it; count it as part of the content.
        let bottom = contentHeight + contentInsets.bottom
        return visible.maxY >= bottom - 0.5
    }
}

#endif

// MARK: - Split scroll sync

#if os(macOS)
typealias SyncScrollView = NSScrollView
#else
typealias SyncScrollView = UIScrollView
#endif

/// Keeps the editor and preview panes of the split display mode at the same
/// fraction of their scrollable content. A user scroll on either side moves
/// the other; scrolls this class performs itself are not echoed back.
final class SplitScrollSync {

    enum Side: Hashable {
        case editor
        case preview

        var other: Side {
            self == .editor ? .preview : .editor
        }
    }

    private final class WeakBox {
        weak var value: SyncScrollView?

        init(_ value: SyncScrollView) {
            self.value = value
        }
    }

    private var views: [Side: WeakBox] = [:]
    private var lastApplied: [Side: CGFloat] = [:]
    private var isApplying = false

    #if os(macOS)
    private var observers: [Side: NSObjectProtocol] = [:]
    #else
    private var observations: [Side: NSKeyValueObservation] = [:]
    #endif

    deinit {
        #if os(macOS)
        for observer in observers.values {
            NotificationCenter.default.removeObserver(observer)
        }
        #else
        for observation in observations.values {
            observation.invalidate()
        }
        #endif
    }

    // MARK: Attach & detach

    func attach(_ scrollView: SyncScrollView, as side: Side) {
        #if os(macOS)
        if let observer = observers[side] {
            NotificationCenter.default.removeObserver(observer)
        }
        observers[side] = nil
        #else
        observations[side]?.invalidate()
        observations[side] = nil
        #endif

        views[side] = WeakBox(scrollView)
        lastApplied[side] = nil

        #if os(macOS)
        scrollView.contentView.postsBoundsChangedNotifications = true
        observers[side] = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: scrollView.contentView,
            queue: .main
        ) { [weak self, weak scrollView] _ in
            guard let self, let scrollView else { return }
            guard self.views[side]?.value === scrollView else { return }
            self.didScroll(side)
        }
        #else
        observations[side] = scrollView.observe(
            \.contentOffset,
            options: [.new]
        ) { [weak self, weak scrollView] _, _ in
            guard let self, let scrollView else { return }
            guard self.views[side]?.value === scrollView else { return }
            self.didScroll(side)
        }
        #endif
    }

    func detach(_ scrollView: SyncScrollView) {
        guard let side = views.first(where: {
            $0.value.value === scrollView
        })?.key else {
            return
        }

        #if os(macOS)
        if let observer = observers[side] {
            NotificationCenter.default.removeObserver(observer)
        }
        observers[side] = nil
        #else
        observations[side]?.invalidate()
        observations[side] = nil
        #endif
        views[side] = nil
        lastApplied[side] = nil
    }

    // MARK: Sync

    private func didScroll(_ side: Side) {
        guard !isApplying else { return }
        guard
            let source = views[side]?.value,
            let target = views[side.other]?.value
        else {
            return
        }

        let sourceProgress = progress(of: source)
        if let last = lastApplied[side],
           abs(last - sourceProgress) < 0.001 {
            // This is the echo of a scroll this class applied.
            return
        }

        apply(sourceProgress, to: target)
        lastApplied[side.other] = progress(of: target)
    }

    // MARK: Geometry

    private func scrollRange(
        of scrollView: SyncScrollView
    ) -> (min: CGFloat, range: CGFloat)? {
        #if os(macOS)
        let visible = scrollView.documentVisibleRect
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let insets = scrollView.contentInsets
        let minY = -insets.top
        let maxY = max(
            minY,
            documentHeight + insets.bottom - visible.height
        )
        #else
        let insets = scrollView.adjustedContentInset
        let minY = -insets.top
        let maxY = max(
            minY,
            scrollView.contentSize.height
                + insets.bottom
                - scrollView.bounds.height
        )
        #endif

        let range = maxY - minY
        guard range > 0.5 else { return nil }
        return (minY, range)
    }

    private func progress(of scrollView: SyncScrollView) -> CGFloat {
        guard let (minY, range) = scrollRange(of: scrollView) else {
            return 0
        }

        #if os(macOS)
        let offset = scrollView.documentVisibleRect.minY
        #else
        let offset = scrollView.contentOffset.y
        #endif

        return min(max((offset - minY) / range, 0), 1)
    }

    private func apply(_ progress: CGFloat, to scrollView: SyncScrollView) {
        guard let (minY, range) = scrollRange(of: scrollView) else { return }

        isApplying = true
        #if os(macOS)
        let clipView = scrollView.contentView
        clipView.scroll(
            to: NSPoint(
                x: clipView.bounds.origin.x,
                y: minY + progress * range
            )
        )
        scrollView.reflectScrolledClipView(clipView)
        #else
        scrollView.setContentOffset(
            CGPoint(
                x: scrollView.contentOffset.x,
                y: minY + progress * range
            ),
            animated: false
        )
        #endif
        isApplying = false
    }
}
