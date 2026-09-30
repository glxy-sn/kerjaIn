import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PDFKit

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
            CustomizeSectionsSheet(sections: $viewModel.sections)
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

                // Generate / Regenerate CV button
                Button {
                    viewModel.generateCV()
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isGenerating {
                            ProgressView()
                                .controlSize(.small)
                                .colorScheme(.dark)
                        }
                        Text(viewModel.generateButtonLabel)
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

                // Loading progress bar — shown while generating
                if viewModel.isGenerating {
                    GeneratingProgressCard(steps: viewModel.steps)
                } else {
                    // Pipeline steps — shown after generation
                    PipelineCard(
                        steps: viewModel.steps,
                        isLive: viewModel.isLivePipeline && viewModel.generationDone,
                        modelName: MLXInferenceService.shared.selectedModel.displayName,
                        errorMessage: viewModel.lastPipelineError
                    )
                }

                // Improve CV section — appears after first generation
                if viewModel.generationDone {
                    if viewModel.cvFullyOptimized {
                        CVOptimizedBanner(score: viewModel.scoreBreakdown)
                    } else if !viewModel.feedbackItems.isEmpty {
                        ImproveCVSection(viewModel: viewModel)
                    }
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
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
    }
}

// MARK: - Generating Progress Card

private struct GeneratingProgressCard: View {
    let steps: [AgentStep]

    private let barH: CGFloat    = 22
    private let mascotW: CGFloat = 52
    private let mascotH: CGFloat = 58
    private let bobAmp: CGFloat  = 6

    // Two SVG frames that alternate to produce a walking animation
    private let frames = ["KerjaInMascot", "KerjaInMascot2"]
    private let frameInterval: TimeInterval = 0.28   // seconds per step

    @State private var animatedProgress: Double = 0
    @State private var bobOffset: CGFloat = 0
    @State private var frameIndex: Int = 0

    private var targetProgress: Double {
        let total = Double(steps.count)
        guard total > 0 else { return 0 }
        let done    = Double(steps.filter { $0.state == .done }.count)
        let running = steps.contains(where: { $0.state == .running }) ? 0.5 : 0.0
        return min(1.0, (done + running) / total)
    }

    private var currentStepLabel: String {
        if let s = steps.first(where: { $0.state == .running }) { return s.title }
        if let s = steps.last(where:  { $0.state == .done    }) { return s.title }
        return "Preparing…"
    }

    var body: some View {
        VStack(spacing: 10) {
            VStack(spacing: 0) {
                // Mascot row — explicit height so the head is never clipped
                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let filledW = w * animatedProgress
                    let cx = min(max(filledW, mascotW / 2), w - mascotW / 2)

                    // Alternate between two frames — no cross-fade, hard switch for crisp walk cycle
                    Image(frames[frameIndex])
                        .resizable()
                        .scaledToFit()
                        .frame(width: mascotW, height: mascotH)
                        .position(x: cx, y: h - mascotH / 2 + bobOffset)
                }
                .frame(height: mascotH + bobAmp + 4)

                // Bar row
                GeometryReader { geo in
                    let w = geo.size.width
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: barH / 2)
                            .fill(Color.appSeparator)
                        RoundedRectangle(cornerRadius: barH / 2)
                            .fill(Color.inkPrimary)
                            .frame(width: max(0, w * animatedProgress))
                    }
                    .frame(width: w, height: barH)
                }
                .frame(height: barH)
            }

            // Small step label — fades on change
            Text(currentStepLabel)
                .font(.system(size: 11.5))
                .foregroundStyle(Color.inkSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .id(currentStepLabel)
                .transition(.opacity)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.appSeparator, lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = targetProgress
            }
            // Bob synced to frame interval: up on frame 0, down on frame 1
            withAnimation(.easeInOut(duration: frameInterval).repeatForever(autoreverses: true)) {
                bobOffset = -bobAmp
            }
        }
        .onChange(of: targetProgress) { _, newVal in
            withAnimation(.easeInOut(duration: 0.45)) {
                animatedProgress = newVal
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(frameInterval * 1_000_000_000))
                frameIndex = frameIndex == 0 ? 1 : 0
            }
        }
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
        .background(Color.cardSurface)
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

// MARK: - CV Optimized Banner

private struct CVOptimizedBanner: View {
    let score: MatchScoreBreakdown?

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.statusOfferBg)
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color.statusOffer)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("CV Fully Optimized")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text("All improvement rounds complete. Export your CV when ready.")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            if let score {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(score.matchScore)%")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Color.inkPrimary)
                    Text("match")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.inkTertiary)
                }
            }
        }
        .padding(16)
        .background(Color.cardSurface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.statusOffer.opacity(0.4), lineWidth: 1))
        .shadow(color: .black.opacity(0.04), radius: 1)
        .shadow(color: .black.opacity(0.04), radius: 18, y: 5)
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
            .background(Color.cardSurface)
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

            // Footer — directs user back to the single Generate button at the top
            let appliedCount = viewModel.feedbackItems.filter { $0.state == .applied }.count
            if appliedCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.statusOffer)
                    Text("Click **\(viewModel.generateButtonLabel)** above to rebuild your CV.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.inkSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.statusOfferBg)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.statusOffer.opacity(0.3), lineWidth: 1))
            } else {
                Text("Apply suggestions above, then the Generate button will activate to rebuild your CV.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color.inkTertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
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
        .background(Color.cardSurface)
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
                        .background(Color.primaryAction)
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
        .background(Color.cardSurface)
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
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        let name = cvData.profile.name.isEmpty
            ? "My_CV"
            : cvData.profile.name.replacingOccurrences(of: " ", with: "_")
        panel.nameFieldStringValue = "\(name).pdf"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            // Render the full document without ScrollView clipping, using vector PDF
            let pageWidth: CGFloat = 612  // US Letter points
            let exportView = CVDocumentView(cvData: cvData)
                .padding(.horizontal, 40)
                .padding(.vertical, 36)
                .frame(width: pageWidth)

            let host = NSHostingView(rootView: exportView)
            host.frame = CGRect(x: 0, y: 0, width: pageWidth, height: 8000)
            let fittingHeight = max(host.fittingSize.height, 792)  // at least US Letter height
            host.frame = CGRect(x: 0, y: 0, width: pageWidth, height: fittingHeight)

            let pdfData = host.dataWithPDF(inside: host.bounds)
            // Post-process: inject PDF link annotations for each named profile link
            let finalData = Self.injectPDFLinks(into: pdfData, links: cvData.profile.links)
            try? finalData.write(to: url)
        }
    }

    // Searches the rendered PDF for each link label and adds a PDFAnnotation so
    // the link is clickable in any PDF reader. dataWithPDF generates vector text
    // but no hyperlink metadata — this adds it after the fact.
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

    var body: some View {
        @Bindable var viewModel = viewModel
        VStack(spacing: 12) {
            CVPreviewCard(cvData: viewModel.filteredCVData, forceEmpty: !viewModel.generationDone)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if viewModel.generationDone {
                Button {
                    exportPDF(cvData: viewModel.filteredCVData)
                } label: {
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
        }
        .padding(.top, 24)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Customize Sections Sheet

private struct CustomizeSectionsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var sections: [SectionConfig]

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
                        .background(Color.cardSurface)
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
                    sections = CVGeneratorViewModel.defaultSections
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
            .background(Color.primaryAction)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}


