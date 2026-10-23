//
//  StudyActionButtonStyle.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//

import SwiftUI

struct StudyActionButtonStyle: ButtonStyle {

    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                tint,
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .shadow(color: tint.opacity(0.28), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}
