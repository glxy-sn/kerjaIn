import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

struct CVGeneratorView: View {
    var viewModel: CVGeneratorViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        HStack(alignment: .top, spacing: 0) {
            LeftPanel(viewModel: viewModel)
                .frame(width: 420)

            Divider()

            RightPanel(viewModel: viewModel)
                .frame(maxWidth: .infinity)
        }
        .background(Color.appBackground)
        .navigationTitle("CV Generator")
        .toolbar {
            // Forces macOS to render the toolbar row and show the navigation title
            ToolbarItem(placement: .automatic) {
                Color.clear.frame(width: 1, height: 22)
            }
        }
        .onAppear { viewModel.load() }
        .sheet(isPresented: $viewModel.showCustomize) {
            CustomizeSectionsSheet()
        }
    }
}

// MARK: - Left Panel

private struct LeftPanel: View {
    var viewModel: CVGeneratorViewModel

    var body: some View {
        @Bindable var viewModel = viewModel
        ScrollView {
            VStack(spacing: 14) {
                // Model picker
                ModelPickerCard()

                // Job description input
                JDCard(text: $viewModel.jobDescription)

                // Customize sections — lives here so it's clearly a pre-generate setting
                HStack {
                    Spacer()
                    Button { viewModel.showCustomize = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 11))
                            Text("Customize sections")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundStyle(Color.inkSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Generate CV button — disabled once generated unless JD changes
                Button {
                    viewModel.generateCV()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                                .colorScheme(.dark)
                        }
                        Text(viewModel.isGenerating ? "Generating..." : "Generate CV")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(viewModel.canGenerate && !viewModel.isGenerating
                                ? Color.inkPrimary
                                : Color.inkTertiary.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canGenerate || viewModel.isGenerating)

                // Pipeline steps
                PipelineCard(
                    steps: viewModel.steps,
                    isLive: viewModel.isLivePipeline && viewModel.generationDone,
                    modelName: MLXInferenceService.shared.selectedModel.displayName,
                    errorMessage: viewModel.lastPipelineError
                )

                // Improve CV section — appears after first generation
                if viewModel.generationDone {
                    ImproveCVSection(viewModel: viewModel)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - JD Card

private struct JDCard: View {
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Job Description")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.inkPrimary)

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text("Paste the job description here...")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.inkTertiary)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .allowsHitTesting(false)
                }
                TextEditor(text: $text)
                    .font(.system(size: 13))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: 140)
                    .padding(2)
            }
            .background(Color.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 9))
            .overlay(
                RoundedRectangle(cornerRadius: 9).stroke(Color.appSeparator, lineWidth: 1)
            )
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
    }
}

// MARK: - Pipeline Card

private struct PipelineCard: View {
    let steps: [AgentStep]
    var isLive: Bool = false
    var modelName: String = ""
    var errorMessage: String = ""

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                HStack(spacing: 13) {
                    Text("\(step.id)")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.inkTertiary)
                        .frame(width: 22, height: 22)
                        .background(Color.fieldBackground)
                        .clipShape(Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.inkPrimary)
                        Text(step.subtitle)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.inkTertiary)
                    }

                    Spacer()

                    StepStatusBadge(state: step.state)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 15)

                if index < steps.count - 1 {
                    Divider()
                        .padding(.horizontal, 18)
                }
            }

            Divider()

            // Mode indicator — shows whether a real model or demo data was used
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isLive ? Color.statusOffer : Color.inkTertiary)
                        .frame(width: 6, height: 6)
                    Text(isLive ? "Live · \(modelName)" : "Demo mode — load a model to generate real output")
                        .font(.system(size: 11))
                        .foregroundStyle(isLive ? Color.statusOffer : Color.inkTertiary)
                }
                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.system(size: 10).monospaced())
                        .foregroundStyle(Color.statusRejected)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineLimit(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
    }
}

private struct StepStatusBadge: View {
    let state: AgentStepState

    var body: some View {
        switch state {
        case .waiting:
            Text("Waiting")
                .font(.system(size: 11.5))
                .foregroundStyle(Color.inkTertiary)
        case .running:
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Running")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.statusApplied)
            }
        case .done:
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 10, weight: .bold))
                Text("Done")
                    .font(.system(size: 11.5, weight: .semibold))
            }
            .foregroundStyle(Color.statusOffer)
        }
    }
}

// MARK: - Improve CV Section

private struct ImproveCVSection: View {
    var viewModel: CVGeneratorViewModel
    @State private var currentIndex: Int = 0
    @State private var goingForward: Bool = true
    @State private var showScoreInfo = false

    private var items: [FeedbackItem] { viewModel.feedbackItems }

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.statusInterviewBg)
                        .frame(width: 36, height: 36)
                    Image(systemName: "sparkles")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.statusInterview)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Improve CV")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("Gap Reviewer found ways to strengthen this. You supply the facts, the agent never invents them.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                if let score = viewModel.scoreBreakdown {
                    VStack(alignment: .trailing, spacing: 5) {
                        // Score + ⓘ button
                        HStack(spacing: 5) {
                            Text("\(score.matchScore)%")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Color.inkPrimary)
                            Text("match")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.inkTertiary)
                                .padding(.top, 4)
                            Button {
                                showScoreInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showScoreInfo, arrowEdge: .trailing) {
                                ScoreBreakdownPopover(breakdown: score)
                            }
                        }
                        // Readiness Gate badge
                        ReadinessGateBadge(gate: score.gate)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
            .shadow(color: .black.opacity(0.04), radius: 1)
            .shadow(color: .black.opacity(0.04), radius: 18, y: 5)

            // Carousel — one card at a time, navigation inside card footer
            if !items.isEmpty {
                let safeIndex = min(currentIndex, items.count - 1)
                FeedbackItemCard(
                    item: items[safeIndex],
                    currentIndex: safeIndex,
                    totalCount: items.count,
                    onApply: {
                        viewModel.applyFeedback(id: items[safeIndex].id)
                        // Auto-advance to next slide on apply
                        if currentIndex < items.count - 1 {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                goingForward = true
                                currentIndex += 1
                            }
                        }
                    },
                    onSkip: { viewModel.skipFeedback(id: items[safeIndex].id) },
                    onPrev: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            goingForward = false
                            currentIndex = max(0, currentIndex - 1)
                        }
                    },
                    onNext: {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            goingForward = true
                            currentIndex = min(items.count - 1, currentIndex + 1)
                        }
                    },
                    onInputChange: { viewModel.updateFeedbackInput(id: items[safeIndex].id, text: $0) }
                )
                .id(safeIndex)
                .transition(goingForward
                    ? .asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading))
                    : .asymmetric(insertion: .move(edge: .leading),  removal: .move(edge: .trailing))
                )
            }

            // Footer
            VStack(spacing: 12) {
                Text("Applied changes are saved back to your knowledge base, so you won't be asked again.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button {
                    viewModel.regenerateCV()
                } label: {
                    Text("Regenerate CV")
                        .font(.system(size: 14, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.inkPrimary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isGenerating)
            }
        }
    }
}

// MARK: - Readiness Gate Badge

private struct ReadinessGateBadge: View {
    let gate: ReadinessGate

    private var color: Color {
        switch gate {
        case .ready:        return Color.statusOffer
        case .needsWork:    return Color.statusInterview
        case .notQualified: return Color.statusRejected
        }
    }

    private var bgColor: Color {
        switch gate {
        case .ready:        return Color.statusOfferBg
        case .needsWork:    return Color.statusInterviewBg
        case .notQualified: return Color.statusRejectedBg
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: gate.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(gate.label)
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(bgColor)
        .clipShape(Capsule())
    }
}

// MARK: - Score Breakdown Popover

private struct ScoreBreakdownPopover: View {
    let breakdown: MatchScoreBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title
            Text("How is this score calculated?")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.inkPrimary)

            Divider()

            // Score summary
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(breakdown.matchScore)%")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text("match score")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
            }

            // Breakdown table
            VStack(spacing: 0) {
                PopoverTableHeader()
                Divider()
                PopoverTableRow(
                    label: "Must-have",
                    weight: "3",
                    matched: breakdown.mustHaveMatched,
                    partial: breakdown.mustHavePartial,
                    missing: breakdown.mustHaveMissing,
                    total: breakdown.mustHaveTotal
                )
                Divider()
                PopoverTableRow(
                    label: "Nice-to-have",
                    weight: "1",
                    matched: breakdown.niceToHaveMatched,
                    partial: breakdown.niceToHavePartial,
                    missing: breakdown.niceToHaveTotal - breakdown.niceToHaveMatched - breakdown.niceToHavePartial,
                    total: breakdown.niceToHaveTotal
                )
            }
            .background(Color.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))

            // Formula note
            VStack(alignment: .leading, spacing: 4) {
                Text("Formula")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                Text("Σ(weight × match) / Σ(max weight)")
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(Color.inkSecondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Matched = 1.0  ·  Partial = 0.5  ·  Missing = 0.0")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkTertiary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                Text(String(format: "= %.1f / %.0f = %d%%", breakdown.numerator, breakdown.denominator, breakdown.matchScore))
                    .font(.system(size: 11).monospaced())
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Divider()

            // Readiness Gate
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Text("Readiness Gate")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color.inkSecondary)
                    ReadinessGateBadge(gate: breakdown.gate)
                }

                switch breakdown.gate {
                case .ready:
                    Text("All must-have requirements are fully matched.")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Color.inkSecondary)
                case .needsWork(let skills):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("All must-haves are present, but \(skills.count == 1 ? "1 is" : "\(skills.count) are") only partially matched:")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(skills, id: \.self) { skill in
                            HStack(spacing: 5) {
                                Circle().fill(Color.statusInterview).frame(width: 5, height: 5)
                                Text(skill)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.inkPrimary)
                                Text("(partial)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                        }
                    }
                case .notQualified(let skills):
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(skills.count == 1 ? "1 must-have is" : "\(skills.count) must-haves are") missing from your profile:")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Color.inkSecondary)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(skills, id: \.self) { skill in
                            HStack(spacing: 5) {
                                Circle().fill(Color.statusRejected).frame(width: 5, height: 5)
                                Text(skill)
                                    .font(.system(size: 11.5, weight: .medium))
                                    .foregroundStyle(Color.inkPrimary)
                                Text("(missing)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.inkTertiary)
                            }
                        }
                    }
                }

                Text("Nice-to-haves only affect the match score, never the gate.")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.inkTertiary)
                    .italic()
            }
        }
        .padding(18)
        .frame(width: 360)
    }
}

private struct PopoverTableHeader: View {
    var body: some View {
        HStack {
            Text("Type").frame(maxWidth: .infinity, alignment: .leading)
            Text("W").frame(width: 22, alignment: .center)
            Text("✓").frame(width: 28, alignment: .center)
            Text("≈").frame(width: 28, alignment: .center)
            Text("✗").frame(width: 28, alignment: .center)
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(Color.inkTertiary)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct PopoverTableRow: View {
    let label: String
    let weight: String
    let matched: Int
    let partial: Int
    let missing: Int
    let total: Int

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Text("\(total) requirements")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.inkTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(weight)
                .font(.system(size: 11.5, weight: .bold))
                .foregroundStyle(Color.inkSecondary)
                .frame(width: 22, alignment: .center)
            Text("\(matched)")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.statusOffer)
                .frame(width: 28, alignment: .center)
            Text("\(partial)")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Color.statusInterview)
                .frame(width: 28, alignment: .center)
            Text("\(missing)")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(missing > 0 ? Color.statusRejected : Color.inkTertiary)
                .frame(width: 28, alignment: .center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color.white)
    }
}

// MARK: - Feedback Item Card

private struct FeedbackItemCard: View {
    let item: FeedbackItem
    let currentIndex: Int
    let totalCount: Int
    let onApply: () -> Void
    let onSkip: () -> Void
    let onPrev: () -> Void
    let onNext: () -> Void
    let onInputChange: (String) -> Void

    @State private var inputText: String = ""

    private var borderColor: Color {
        item.state == .applied ? Color.statusOffer.opacity(0.5) : Color.appSeparator
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Tag row + state badge
            HStack(spacing: 8) {
                tagChip
                Spacer()
                switch item.state {
                case .applied:
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                        Text("Applied")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(Color.statusOffer)
                case .skipped:
                    Text("Skipped")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                case .pending:
                    EmptyView()
                }
            }

            // Title
            if !item.title.isEmpty {
                Text(item.title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
            }

            // Blockquote-style bullet quote
            if !item.bulletQuote.isEmpty {
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appSeparator)
                        .frame(width: 3)
                    Text(item.bulletQuote)
                        .font(.system(size: 13).italic())
                        .foregroundStyle(Color.inkSecondary)
                }
            }

            // Missing skill description with bold phrases
            if !item.missingDesc.isEmpty {
                Text(styledMissingDesc)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Question + input (always shown when present — editable even after apply/skip)
            if !item.question.isEmpty {
                Text(item.question)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkPrimary)

                TextField(item.inputPlaceholder, text: $inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.fieldBackground)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onChange(of: inputText) { _, v in onInputChange(v) }

                Text(item.helperText)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.inkTertiary)
            }

            Divider()

            // Footer: action buttons (left) + carousel nav (right)
            HStack(spacing: 10) {
                if item.canApply {
                    Button("Apply") { onApply() }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .background(Color.inkPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .buttonStyle(.plain)

                    Button("Skip") { onSkip() }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color.inkSecondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 7)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1.5))
                        .buttonStyle(.plain)
                }

                Spacer()

                // ← dots →
                HStack(spacing: 10) {
                    Button { onPrev() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(currentIndex == 0 ? Color.appSeparator : Color.inkSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex == 0)

                    HStack(spacing: 5) {
                        ForEach(0..<totalCount, id: \.self) { idx in
                            Circle()
                                .fill(idx == currentIndex ? Color.inkPrimary : Color.appSeparator)
                                .frame(width: idx == currentIndex ? 6 : 4,
                                       height: idx == currentIndex ? 6 : 4)
                        }
                    }

                    Button { onNext() } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(currentIndex == totalCount - 1 ? Color.appSeparator : Color.inkSecondary)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentIndex == totalCount - 1)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(borderColor, lineWidth: item.state == .applied ? 1.5 : 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
        .onAppear { inputText = item.inputText }
    }

    private var tagChip: some View {
        Text(item.tagLabel)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(item.canApply ? Color.statusInterview : Color.statusRejected)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(item.canApply ? Color.statusInterviewBg : Color.statusRejectedBg)
            .clipShape(Capsule())
    }

    private var styledMissingDesc: AttributedString {
        var str = AttributedString(item.missingDesc)
        for phrase in item.boldPhrases {
            if let range = str.range(of: phrase) {
                str[range].inlinePresentationIntent = .stronglyEmphasized
            }
        }
        return str
    }
}

// MARK: - Right Panel

private struct RightPanel: View {
    var viewModel: CVGeneratorViewModel

    @MainActor
    private func exportPDF(cvData: CVData) {
        let renderer = ImageRenderer(content: CVExportContent(cvData: cvData))
        renderer.scale = 2
        guard let nsImage = renderer.nsImage else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let name = cvData.profile.name.isEmpty
            ? "My_CV"
            : cvData.profile.name.replacingOccurrences(of: " ", with: "_")
        panel.nameFieldStringValue = "\(name).pdf"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let doc = PDFDocument()
            if let page = PDFPage(image: nsImage) {
                doc.insert(page, at: 0)
            }
            _ = doc.write(to: url)
        }
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 12) {
            CVPreviewCard(cvData: viewModel.filteredCVData, forceEmpty: !viewModel.generationDone)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.generationDone {
                Button {
                    exportPDF(cvData: viewModel.cvData)
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 13))
                        Text("Export PDF")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.inkPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - CV Export Content

private struct CVExportContent: View {
    let cvData: CVData
    var body: some View {
        CVPreviewCard(cvData: cvData, forceEmpty: false)
            .frame(width: 560)
    }
}

// MARK: - Customize Sections Sheet

private struct SectionConfig {
    var name: String
    var detail: String
    var enabled: Bool
}

private struct CustomizeSectionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var sections: [SectionConfig] = [
        SectionConfig(name: "Professional Summary", detail: "1 paragraph",       enabled: true),
        SectionConfig(name: "Experience",           detail: "3 selected",        enabled: true),
        SectionConfig(name: "Projects",             detail: "2 selected",        enabled: true),
        SectionConfig(name: "Skills",               detail: "8 tags",            enabled: true),
        SectionConfig(name: "Education",            detail: "1 entry",           enabled: true),
        SectionConfig(name: "Certifications",       detail: "off for this role", enabled: false),
        SectionConfig(name: "Honors & Awards",      detail: "off for this role", enabled: false),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Customize CV sections")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text("Drag to reorder · toggle to include. Applies to this generation.")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.inkSecondary)
            }
            .padding(.top, 28)
            .padding(.horizontal, 28)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(sections.indices, id: \.self) { idx in
                        HStack(spacing: 12) {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.inkTertiary)

                            Text(sections[idx].name)
                                .font(.system(size: 14, weight: sections[idx].enabled ? .semibold : .regular))
                                .foregroundStyle(sections[idx].enabled ? Color.inkPrimary : Color.inkTertiary)

                            Spacer()

                            Text(sections[idx].detail)
                                .font(.system(size: 11.5))
                                .foregroundStyle(Color.inkTertiary)

                            Toggle("", isOn: Binding(
                                get: { sections[idx].enabled },
                                set: { sections[idx].enabled = $0 }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10).stroke(Color.appSeparator, lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }

            Divider()

            HStack(spacing: 12) {
                Spacer()
                Button("Reset to default") {
                    for i in sections.indices { sections[i].enabled = i < 5 }
                }
                .buttonStyle(SheetSecondaryStyle())

                Button("Apply") { dismiss() }
                    .buttonStyle(SheetPrimaryStyle())
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .frame(width: 500, height: 560)
    }
}

private struct SheetSecondaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.inkPrimary)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appSeparator, lineWidth: 1.5))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct SheetPrimaryStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            .background(Color.inkPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

// MARK: - Model Picker Card

private struct ModelPickerCard: View {
    @State private var service = MLXInferenceService.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "cpu")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkSecondary)
                Text("Model")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.inkPrimary)
                Spacer()
                statusChip
            }

            Picker("", selection: Binding(
                get: { service.selectedModel },
                set: { service.switchModel(to: $0) }
            )) {
                ForEach(MLXModel.allCases) { model in
                    Text("\(model.displayName)  \(model.sizeLabel)")
                        .tag(model)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if !service.isReady {
                Button {
                    Task { await service.loadSelectedModel() }
                } label: {
                    HStack(spacing: 6) {
                        if case .downloading = service.loadState {
                            ProgressView()
                                .controlSize(.mini)
                        } else if case .loading = service.loadState {
                            ProgressView()
                                .controlSize(.mini)
                        }
                        Text(loadButtonLabel)
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 7)
                    .background(Color.statusApplied.opacity(0.1))
                    .foregroundStyle(Color.statusApplied)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.statusApplied.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                if case .downloading(let p) = service.loadState {
                    ProgressView(value: p)
                        .tint(Color.statusApplied)
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
    }

    private var isLoading: Bool {
        switch service.loadState {
        case .downloading, .loading: return true
        default: return false
        }
    }

    private var loadButtonLabel: String {
        switch service.loadState {
        case .downloading(let p): return "Downloading \(Int(p * 100))%…"
        case .loading:            return "Loading into memory…"
        case .failed:             return "Retry"
        default:                  return "Load Model"
        }
    }

    private var statusChip: some View {
        let (label, color, bg): (String, Color, Color) = {
            switch service.loadState {
            case .ready:
                return (service.selectedModel.displayName, Color.statusOffer, Color.statusOfferBg)
            case .downloading, .loading:
                return ("Loading…", Color.statusInterview, Color.statusInterviewBg)
            case .failed:
                return ("Error", Color.statusRejected, Color.statusRejectedBg)
            default:
                return ("Not loaded", Color.inkTertiary, Color.hoverBackground)
            }
        }()
        return Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(bg)
            .clipShape(Capsule())
    }
}
