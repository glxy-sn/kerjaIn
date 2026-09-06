import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct EditProfileSheet: View {
    @Binding var profile: UserProfile
    let onSave: () -> Void
    let onCancel: () -> Void

    @State private var newLinkLabel = ""
    @State private var newLinkURL   = ""

    var body: some View {
        VStack(spacing: 0) {
            // Sheet header
            HStack(alignment: .center) {
                Text("Edit Profile")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                Button { onCancel() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(7)
                        .background(Color.fieldBackground)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.top, 28)
            .padding(.bottom, 20)

            Divider()

            ScrollView {
                VStack(spacing: 18) {
                    // Basic Info
                    SheetCard(title: "Basic Info") {
                        SheetField(label: "Full name", value: $profile.name,    placeholder: "e.g. Tiara Tsabita")
                        SheetField(label: "Email",     value: $profile.email,   placeholder: "tiara@example.com")
                        SheetField(label: "Phone",     value: $profile.phone,   placeholder: "+62 812 …")
                        SheetField(label: "Location",  value: $profile.address, placeholder: "Jakarta, ID")
                        SheetField(label: "Summary",   value: $profile.summary, placeholder: "A short bio for the top of your CV…", multiline: true)
                    }

                    // Portfolio & Links
                    SheetCard(title: "Portfolio & Links") {
                        if !profile.links.isEmpty {
                            VStack(spacing: 6) {
                                ForEach(profile.links.indices, id: \.self) { idx in
                                    HStack(spacing: 8) {
                                        Image(systemName: "link")
                                            .font(.system(size: 11))
                                            .foregroundStyle(Color.statusApplied)
                                        VStack(alignment: .leading, spacing: 1) {
                                            if !profile.links[idx].label.isEmpty {
                                                Text(profile.links[idx].label)
                                                    .font(.system(size: 11, weight: .semibold))
                                                    .foregroundStyle(Color.inkSecondary)
                                            }
                                            Text(profile.links[idx].url)
                                                .font(.system(size: 12.5))
                                                .foregroundStyle(Color.statusApplied)
                                                .lineLimit(1)
                                                .truncationMode(.middle)
                                        }
                                        Spacer()
                                        Button {
                                            profile.links.remove(at: idx)
                                        } label: {
                                            Image(systemName: "xmark")
                                                .font(.system(size: 10, weight: .medium))
                                                .foregroundStyle(Color.inkTertiary)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 9)
                                    .background(Color.fieldBackground)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }

                        // Add new link: two text fields side by side
                        HStack(spacing: 8) {
                            TextField("Type (e.g. GitHub, Portfolio)", text: $newLinkLabel)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Color.fieldBackground)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .frame(maxWidth: 160)

                            TextField("URL", text: $newLinkURL)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13))
                                .padding(.horizontal, 12).padding(.vertical, 9)
                                .background(Color.fieldBackground)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onSubmit { addLink() }
                        }

                        Button("+ Add link") { addLink() }
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(newLinkURL.trimmingCharacters(in: .whitespaces).isEmpty
                                            ? Color.inkTertiary : Color.statusApplied)
                            .buttonStyle(.plain)
                            .disabled(newLinkURL.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                .padding(28)
            }

            Divider()

            // Footer
            HStack(spacing: 10) {
                Spacer()
                Button("Cancel") { onCancel() }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.inkSecondary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.appSeparator, lineWidth: 1.5))
                    .buttonStyle(.plain)

                Button("Save") { onSave() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 9)
                    .background(Color.inkPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .frame(width: 520)
        .background(Color.appBackground)
    }

    // MARK: - Helpers

    private func addLink() {
        let url = newLinkURL.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        let label = newLinkLabel.trimmingCharacters(in: .whitespaces)
        profile.links.append(ProfileLink(label: label, url: url))
        newLinkLabel = ""
        newLinkURL   = ""
    }

}

// MARK: - Sheet subviews

private struct SheetCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.inkPrimary)
            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
    }
}

private struct SheetField: View {
    let label: String
    @Binding var value: String
    var placeholder: String = ""
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.inkSecondary)
            if multiline {
                TextField(placeholder, text: $value, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .lineLimit(3...6)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.fieldBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                TextField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.fieldBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

// Simple wrapping flow layout for skill chips
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                y += rowHeight + spacing
                x = bounds.minX
                rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
    }
}
