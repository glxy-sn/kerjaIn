import SwiftUI

struct StatusBadge: View {
    let status: ApplicationStatus
    var showChevron: Bool = false

    private var fg: Color {
        switch status {
        case .applied:             return .statusApplied
        case .interview:           return .statusInterview
        case .offer, .hired:       return .statusOffer
        case .rejected:            return .statusRejected
        case .closed:              return .statusClosed
        }
    }

    private var bg: Color {
        switch status {
        case .applied:             return .statusAppliedBg
        case .interview:           return .statusInterviewBg
        case .offer, .hired:       return .statusOfferBg
        case .rejected:            return .statusRejectedBg
        case .closed:              return .statusClosedBg
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(fg)
                .frame(width: 7, height: 7)
            Text(status.rawValue)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(fg)
            if showChevron {
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(fg)
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 4)
        .background(bg)
        .clipShape(Capsule())
        .overlay {
            if showChevron {
                Capsule().stroke(fg, lineWidth: 1.2)
            }
        }
    }
}
