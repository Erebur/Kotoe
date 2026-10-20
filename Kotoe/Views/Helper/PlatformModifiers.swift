//
//  PlatformModifiers.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import SwiftUI

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
}
