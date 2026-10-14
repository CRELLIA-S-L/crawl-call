// The line along the top of the screen that says what each squad stands under
// (FR-VIEW-380): the red squad's order on the left, the blue squad's on the right, each
// on a plate in its own squad's colour.
//
// It exists because an order was the one thing nothing on the phone could show. A match
// in which both squads stood still for two minutes looked identical to one in which
// nobody had been told anything, and the difference — twenty answered calls — was only
// in the frame record (Q-700, ADR-0095).
//
// The order's own words are the commander's and are not translated: `press`,
// `north-east`, `snake` are what the model answered, and FR-VIEW-200's own rationale
// puts what the fighters say outside it. The words around them are in the catalog
// (IF-VIEW-030).
//
// Nothing here takes a touch: the thumb that steers lands anywhere on the left half
// (FR-VIEW-050), the top of it included.
//
// file implements: FR-VIEW-380, FR-VIEW-120, FR-VIEW-200
import SwiftUI

struct SquadOrders: View {
    /// What each squad stands under, as the match holds it (FR-CMD-030, FR-CMD-040).
    let commands: SquadCommands

    var body: some View {
        HStack(alignment: .top, spacing: OrdersBar.spacing) {
            plate(for: .red)
            Spacer(minLength: .zero)
            plate(for: .blue)
        }
        .padding(.horizontal, OrdersBar.margin)
        .padding(.top, OrdersBar.margin)
        .allowsHitTesting(false)
    }

    /// One squad's plate: what it was ordered, over what it was told to worry about.
    private func plate(for squad: Squad) -> some View {
        let standing = commands.of(squad)
        return VStack(alignment: squad == .red ? .leading : .trailing, spacing: .zero) {
            Text(SquadOrders.order(of: standing))
                .font(.system(size: OrdersBar.orderTextSize, weight: .bold, design: .rounded))
            if let threat = SquadOrders.threat(of: standing) {
                Text(threat)
                    .font(.system(size: OrdersBar.threatTextSize, weight: .medium, design: .rounded))
                    .opacity(Interface.markOpacity)
            }
        }
        .foregroundStyle(.black.opacity(Interface.markOpacity))
        .padding(.horizontal, OrdersBar.horizontalPadding)
        .padding(.vertical, OrdersBar.verticalPadding)
        .background(
            RoundedRectangle(cornerRadius: OrdersBar.cornerRadius, style: .continuous)
                .fill(SquadOrders.colour(of: squad).opacity(OrdersBar.plateOpacity))
        )
        .accessibilityElement(children: .combine)
    }

    /// The order and the part of the arena it names, in the commander's own words, or
    /// the game's own line where no commander has spoken to the squad yet.
    static func order(of standing: SquadCommand?) -> String {
        guard let standing else { return TextKey.ordersNone.text() }
        guard let place = standing.place else { return standing.order.rawValue }
        return standing.order.rawValue + " " + place.rawValue
    }

    /// What the squad was told to worry about (FR-CMD-030), in the game's words around
    /// the commander's own; nil where the squad stands under nothing.
    static func threat(of standing: SquadCommand?) -> String? {
        guard let standing else { return nil }
        return String(format: TextKey.ordersThreat.text(), standing.threat.rawValue)
    }

    /// A squad's own colour (FR-VIEW-060) carried towards white, which is what makes
    /// the red squad's plate pink and the blue squad's pale blue while the two stay
    /// the light plates the interface is made of (FR-VIEW-120).
    static func colour(of squad: Squad) -> Color {
        let rgb = BotEntity.colour(for: squad)
        let pale = { (part: Double) in part + (Fraction.whole - part) * OrdersBar.towardsWhite }
        return Color(red: pale(rgb.x), green: pale(rgb.y), blue: pale(rgb.z))
    }
}
