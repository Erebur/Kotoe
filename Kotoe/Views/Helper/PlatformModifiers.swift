//
//  PlatformModifiers.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import SwiftUI

#if os(macOS)
    import AppKit
#endif

extension View {

    /// Inline navigation titles don't exist on macOS.
    @ViewBuilder
    func inlineNavigationBarTitle() -> some View {
        #if os(macOS)
        self
        #else
        navigationBarTitleDisplayMode(.inline)
        #endif
    }

    /// Shows a navigation title only on macOS, where it appears in the
    /// window toolbar instead of duplicating an in-content title.
    @ViewBuilder
    func macNavigationTitle(_ title: String) -> some View {
        #if os(macOS)
        navigationTitle(title)
        #else
        self
        #endif
    }

    /// `fullScreenCover` is unavailable on macOS, where a sheet is used instead.
    @ViewBuilder
    func editorCover<Content: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        #if os(macOS)
        sheet(isPresented: isPresented, content: content)
        #else
        fullScreenCover(isPresented: isPresented, content: content)
        #endif
    }

    /// macOS focuses the first text field as soon as a view or sheet appears,
    /// which leaves the title selected and highlighted. Clear that initial
    /// responder so the screen opens in a calm, read-only state.
    @ViewBuilder
    func clearInitialFocusOnMac() -> some View {
        #if os(macOS)
        self.onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
        }
        #else
        self
        #endif
    }

    /// Compact menu button that blends into a custom card on every platform.
    @ViewBuilder
    func compactMenuStyle() -> some View {
        #if os(macOS)
        self
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        #else
        self.menuIndicator(.hidden)
        #endif
    }

    /// Compact prompt sheets (create subject / create set).
    ///
    /// macOS sizes sheets from their content. Without an explicit width a
    /// `Form` inside a `NavigationStack` collapses into a very narrow,
    /// awkward sheet, so the Mac uses a fixed, content-sized dialog instead.
    @ViewBuilder
    func dialogSheet() -> some View {
        #if os(macOS)
        self
            .frame(width: 440)
            .fixedSize(horizontal: false, vertical: true)
        #else
        self
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        #endif
    }

    /// Large editor sheets get a real size on macOS instead of collapsing to
    /// the intrinsic size of their content.
    @ViewBuilder
    func editorSheetSize(
        width: CGFloat = 680,
        height: CGFloat = 720
    ) -> some View {
        #if os(macOS)
        self.frame(width: width, height: height)
        #else
        self
        #endif
    }

    /// Diagnostic log sheets hold a scrollable list, so they need room on
    /// every platform and can expand to full height on iOS.
    @ViewBuilder
    func logSheetSize(
        width: CGFloat = 520,
        height: CGFloat = 560
    ) -> some View {
        #if os(macOS)
        self.frame(width: width, height: height)
        #else
        self
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        #endif
    }
}
