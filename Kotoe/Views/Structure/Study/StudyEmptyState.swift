//
//  StudyEmptyState.swift
//  Kōtoe
//
//  Created by Simon Weber on 23.10.26.
//

import SwiftUI

/// Shown when the set has no cards to study.
struct StudyEmptyState: View {

    let tint: Color

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 124, height: 124)

                Image(systemName: "rectangle.stack.badge.minus")
                    .font(.system(size: 50))
                    .foregroundStyle(tint)
            }

            Text("studyView.emptyState.title")
                .font(.system(.title2, design: .rounded, weight: .bold))

            Text(
                "studyView.emptyState.message"
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 340)
        }
        .padding(30)
    }
}

// MARK: - Previews

#Preview("Study Empty State") {
    ZStack {
        AmbientBackground(tint: KotoeTheme.accent)
        StudyEmptyState(tint: KotoeTheme.accent)
    }
}
