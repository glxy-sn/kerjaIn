import SwiftUI
import AppKit

struct ShareView: View {
    let extensionContext: NSExtensionContext

    @State private var position = ""
    @State private var company = ""
    @State private var location = ""
    @State private var jobDescription = ""
    @State private var status = JobStatusOption.applied

    enum JobStatusOption: String, CaseIterable {
        case applied   = "Applied"
        case interview = "Interviewing"
        case offer     = "Offer"
        case hired     = "Hired"
        case rejected  = "Rejected"
        case closed    = "Closed"
    }

    private var canSave: Bool { !position.isEmpty && !company.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "briefcase.fill")
                    .foregroundStyle(.blue)
                Text("Add to kerjaIn")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 14)

            Divider()

            ScrollView {
                VStack(spacing: 14) {
                    HStack(spacing: 12) {
                        ShareFormField(label: "Role *", placeholder: "e.g. iOS Engineer", text: $position)
                        ShareFormField(label: "Company *", placeholder: "e.g. Apple", text: $company)
                    }
                    HStack(spacing: 12) {
                        ShareFormField(label: "Location", placeholder: "Remote / city", text: $location)
                        ShareStatusField(status: $status)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Job Description")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.primary)
                        ZStack(alignment: .topLeading) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.textBackgroundColor))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                            if jobDescription.isEmpty {
                                Text("Shared text will appear here…")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 10)
                                    .padding(.top, 8)
                                    .allowsHitTesting(false)
                            }
                            TextEditor(text: $jobDescription)
                                .font(.system(size: 13))
                                .scrollContentBackground(.hidden)
                                .background(.clear)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                        }
                        .frame(minHeight: 120)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }

            Divider()

            HStack(spacing: 10) {
                Button("Cancel") {
                    extensionContext.cancelRequest(
                        withError: NSError(domain: "kerjaIn.share", code: NSUserCancelledError)
                    )
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Save") {
                    saveEntry(openApp: false)
                }
                .buttonStyle(.bordered)
                .disabled(!canSave)

                Button("Save & Open kerjaIn →") {
                    saveEntry(openApp: true)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
        .task { await loadSharedContent() }
    }

    // MARK: - Load shared text/URL from extension context

    private func loadSharedContent() async {
        guard let items = extensionContext.inputItems as? [NSExtensionItem] else { return }
        for item in items {
            for provider in (item.attachments ?? []) {
                if provider.hasItemConformingToTypeIdentifier("public.plain-text") {
                    let text = await loadString(provider: provider, typeIdentifier: "public.plain-text")
                    if let text, !text.isEmpty {
                        jobDescription = text
                        return
                    }
                }
                if provider.hasItemConformingToTypeIdentifier("public.url") {
                    let text = await loadString(provider: provider, typeIdentifier: "public.url")
                    if let text, !text.isEmpty {
                        jobDescription = text
                        return
                    }
                }
            }
        }
    }

    private func loadString(provider: NSItemProvider, typeIdentifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, _ in
                if let str = item as? String {
                    continuation.resume(returning: str)
                } else if let url = item as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else if let data = item as? Data {
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Save

    private func saveEntry(openApp: Bool) {
        let entry = SharedJobEntry(
            id: UUID().uuidString,
            company: company,
            position: position,
            location: location,
            appliedDate: Date(),
            status: status.rawValue,
            notes: jobDescription
        )

        if let ud = UserDefaults(suiteName: "group.com.tiara.kerjaIn") {
            var list: [SharedJobEntry]
            if let existing = ud.data(forKey: "jobHistory"),
               let decoded = try? JSONDecoder().decode([SharedJobEntry].self, from: existing) {
                list = decoded
            } else {
                list = []
            }
            list.append(entry)
            if let data = try? JSONEncoder().encode(list) {
                ud.set(data, forKey: "jobHistory")
                ud.synchronize()
            }
        }

        if openApp, let url = URL(string: "kerjaIn://newJob?id=\(entry.id)") {
            extensionContext.open(url, completionHandler: nil)
        } else {
            extensionContext.completeRequest(returningItems: [], completionHandler: nil)
        }
    }
}

// MARK: - Codable entry matching JobHistory encoding

struct SharedJobEntry: Codable {
    var id: String
    var company: String
    var position: String
    var location: String
    var appliedDate: Date
    var status: String
    var notes: String
}

// MARK: - Sub-views

private struct ShareFormField: View {
    let label: String
    let placeholder: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShareStatusField: View {
    @Binding var status: ShareView.JobStatusOption

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Status")
                .font(.system(size: 12, weight: .semibold))
            Menu {
                ForEach(ShareView.JobStatusOption.allCases, id: \.self) { s in
                    Button(s.rawValue) { status = s }
                }
            } label: {
                HStack {
                    Text(status.rawValue)
                        .font(.system(size: 13))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(NSColor.textBackgroundColor))
                .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(NSColor.separatorColor), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }
}
