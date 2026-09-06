import SwiftUI

struct TopBarView: View {
    let title: String
    @Binding var searchText: String
    var onAdd: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Color.inkPrimary)

            Spacer()

            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkTertiary)
                TextField("Search applications", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .frame(width: 190)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.fieldBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 9)
                    .stroke(Color.appSeparator, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 9))

            if let onAdd {
                Button(action: onAdd) {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                        Text("New")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 7)
                    .background(Color.inkPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 9))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 26)
        .frame(height: 54)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lightSeparator)
                .frame(height: 1)
        }
    }
}
