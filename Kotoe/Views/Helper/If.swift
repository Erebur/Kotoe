//
//  If.swift
//  Kōtoe
//
//  Created by Simon Weber on 21.10.26.
//

import SwiftUI

extension View {
    @ViewBuilder
    func `if`<TrueContent: View>(
        _ condition: Bool,
        @ViewBuilder then thenTransform: (Self) -> TrueContent
    ) -> some View {
        if condition {
            thenTransform(self)
        } else {
            self
        }
    }

    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        @ViewBuilder then thenTransform: (Self) -> TrueContent,
        @ViewBuilder else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            thenTransform(self)
        } else {
            elseTransform(self)
        }
    }
}
