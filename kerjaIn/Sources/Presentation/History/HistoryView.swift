import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

struct HistoryView: View {
    var viewModel: HistoryViewModel
    @State private var selectedCV: GeneratedCV? = nil

    var body: some View {
        List {
            if viewModel.generatedCVs.isEmpty {
                ContentUnavailableView(
                    "No Generated CVs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Generate your first CV from the CV Generator tab.")
                )
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
                .selectionDisabled()
            } else {
                ForEach(viewModel.generatedCVs) { cv in
                    GeneratedCVRow(cv: cv) { selectedCV = cv }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                viewModel.delete(id: cv.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 26, bottom: 6, trailing: 26))
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.appBackground)
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Color.clear.frame(width: 1, height: 22)
            }
        }
        .sheet(item: $selectedCV) { cv in
            CVHistoryDetailSheet(cv: cv) {
                viewModel.delete(id: cv.id)
                selectedCV = nil
            }
        }
        .onAppear { viewModel.load() }
    }
}

// MARK: - Row card

private struct GeneratedCVRow: View {
    let cv: GeneratedCV
    let onTap: () -> Void

    private var logoColor: Color {
        let palette: [Color] = [
            .statusApplied, Color(hex: "111111"), Color(hex: "1db954"),
            Color(hex: "635bff"), Color(hex: "e67e22"), Color(hex: "e91e63")
        ]
        return palette[abs(cv.roleName.hashValue) % palette.count]
    }

    private var displayName: String {
        cv.roleName.isEmpty ? "Generated CV" : cv.roleName
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(logoColor)
                    .frame(width: 46, height: 46)
                    .overlay(
                        Text(String(displayName.prefix(2)).uppercased())
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.inkPrimary)
                    Text(cv.generatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                }

                Spacer()

                if let score = cv.matchScore {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("\(score)%")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(scoreColor(score))
                        Text("match")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.inkTertiary)
                    }
                    .padding(.trailing, 4)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkTertiary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 1)
            .shadow(color: .black.opacity(0.05), radius: 20, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 { return Color.statusOffer }
        if score >= 60 { return Color.statusInterview }
        return Color.statusRejected
    }
}

// MARK: - Detail sheet

private struct CVHistoryDetailSheet: View {
    let cv: GeneratedCV
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    private var displayName: String {
        cv.roleName.isEmpty ? "Generated CV" : cv.roleName
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(displayName)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    HStack(spacing: 8) {
                        Text(cv.generatedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(Color.inkSecondary)
                        if let score = cv.matchScore {
                            Text("\(score)% match")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(score >= 80 ? Color.statusOffer : Color.statusInterview)
                        }
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.inkTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)

            Divider()

            // CV preview
            CVPreviewCard(cvData: cv.cvData, forceEmpty: false)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(16)

            Divider()

            // Footer actions
            HStack(spacing: 12) {
                Button {
                    showDeleteConfirm = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                        Text("Delete")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.statusRejected.opacity(0.08))
                    .foregroundStyle(Color.statusRejected)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.statusRejected.opacity(0.25), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Delete this CV?", isPresented: $showDeleteConfirm) {
                    Button("Delete", role: .destructive) { onDelete() }
                    Button("Cancel", role: .cancel) {}
                }

                Button { exportPDF() } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 13))
                        Text("Export PDF")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.primaryAction)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 680, height: 820)
        .background(Color.appBackground)
    }

    @MainActor
    private func exportPDF() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let name = cv.cvData.profile.name.isEmpty
            ? (cv.roleName.isEmpty ? "My_CV" : cv.roleName.replacingOccurrences(of: " ", with: "_"))
            : cv.cvData.profile.name.replacingOccurrences(of: " ", with: "_")
        panel.nameFieldStringValue = "\(name).pdf"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let pageWidth: CGFloat = 612
            let exportView = CVDocumentView(cvData: cv.cvData)
                .padding(.horizontal, 40)
                .padding(.vertical, 36)
                .frame(width: pageWidth)
            let host = NSHostingView(rootView: exportView)
            host.frame = CGRect(x: 0, y: 0, width: pageWidth, height: 8000)
            let fittingHeight = max(host.fittingSize.height, 792)
            host.frame = CGRect(x: 0, y: 0, width: pageWidth, height: fittingHeight)
            let pdfData = host.dataWithPDF(inside: host.bounds)
            let finalData = Self.injectPDFLinks(into: pdfData, links: cv.cvData.profile.links)
            try? finalData.write(to: url)
        }
    }

    private static func injectPDFLinks(into data: Data, links: [ProfileLink]) -> Data {
        guard let doc = PDFDocument(data: data) else { return data }
        for link in links where !link.label.isEmpty && !link.url.isEmpty {
            let raw = link.url.trimmingCharacters(in: .whitespaces)
            let urlStr = raw.lowercased().hasPrefix("http") ? raw : "https://\(raw)"
            guard let url = URL(string: urlStr) else { continue }
            for sel in doc.findString(link.label, withOptions: .caseInsensitive) {
                guard let page = sel.pages.first else { continue }
                let annot = PDFAnnotation(bounds: sel.bounds(for: page), forType: .link, withProperties: nil)
                annot.action = PDFActionURL(url: url)
                page.addAnnotation(annot)
            }
        }
        return doc.dataRepresentation() ?? data
    }
}
