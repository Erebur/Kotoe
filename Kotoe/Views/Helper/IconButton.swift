//
//  IconButton.swift
//  Kōtoe
//
//  Created by Simon Weber on 20.10.26.
//

import Foundation
import SwiftUI

struct IconButton<Content: View>: View {
    let accentColor: Color
    let symbol: String
    let text: String?
    let shadow: Bool
    let shadowRadius: CGFloat?
    let extraContent: () -> Content

    var disabled: Bool

    init(
        accentColor: Color,
        symbol: String,
        text: String? = nil,
        disabled: Bool = false,
        shadow: Bool = false,
        shadowRadius: CGFloat = 10,
        @ViewBuilder extraContent: @escaping () -> Content = { EmptyView() }
    ) {
        self.accentColor = accentColor
        self.symbol = symbol
        self.text = text
        self.shadow = shadow
        self.shadowRadius = shadowRadius
        self.disabled = disabled
        self.extraContent = extraContent
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 8) {
            extraContent()
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
            if let text {
                Text(text)
                    .font(.system(size: 16, weight: .semibold))
            }
        }
        .foregroundColor(
            accentColor
        )
        .frame(height: 44)
        .padding(.horizontal, 16)
        .background(bgColor())
        .clipShape(Capsule())
        .if(shadow) { view in
            view.shadow(
                color: bgColor(),
                radius: shadowRadius!
            )
        }
    }

    func bgColor() -> Color {
        return disabled ? .gray : accentColor
    }
}

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
