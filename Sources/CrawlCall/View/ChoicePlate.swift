// A plate with a headline and one control, standing where the steering controls stood:
// how a match says it is over (FR-VIEW-190) and how it says it is paused (FR-VIEW-230).
// One view for both, so that the two plates cannot come to look different.
//
// Drawn as the rest of the interface is (FR-VIEW-120): a rounded, light, translucent
// plate and a bold rounded typeface.
//
// file implements: FR-VIEW-190, FR-VIEW-230, FR-VIEW-120, FR-VIEW-200
import SwiftUI

struct ChoicePlate: View {
    let headline: TextKey
    let control: TextKey
    let action: () -> Void

    private let plate = Color.white.opacity(Interface.plateOpacity)
    private let mark = Color.white.opacity(Interface.markOpacity)

    var body: some View {
        VStack(spacing: MatchEndPlate.spacing) {
            Text(headline.key)
                .font(.system(size: MatchEndPlate.headlineSize, weight: .bold, design: .rounded))
                .foregroundStyle(mark)
                .multilineTextAlignment(.center)
            Button(action: action) {
                Text(control.key)
                    .font(.system(size: MatchEndPlate.controlTextSize, weight: .bold, design: .rounded))
                    .foregroundStyle(mark)
                    .padding(.horizontal, MatchEndPlate.controlHorizontalPadding)
                    .padding(.vertical, MatchEndPlate.controlVerticalPadding)
                    .background(Capsule().fill(plate.opacity(Interface.litPlateOpacity)))
                    .overlay(Capsule().strokeBorder(mark, lineWidth: Interface.ringWidth))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(control.key))
        }
        .padding(.horizontal, MatchEndPlate.horizontalPadding)
        .padding(.vertical, MatchEndPlate.verticalPadding)
        .background(RoundedRectangle(cornerRadius: MatchEndPlate.cornerRadius, style: .continuous).fill(plate))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
