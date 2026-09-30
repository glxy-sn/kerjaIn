import SwiftUI

struct ModelLoadingView: View {
    @State private var service = MLXInferenceService.shared
    @State private var frameIndex: Int = 0
    @State private var animatedProgress: Double = 0
    @State private var bobOffset: CGFloat = 0

    private let frames = ["KerjaInMascot", "KerjaInMascot2"]
    private let frameInterval: TimeInterval = 0.28
    private let barH: CGFloat = 22
    private let mascotW: CGFloat = 58
    private let mascotH: CGFloat = 66
    private let bobAmp: CGFloat = 6

    private var targetProgress: Double {
        switch service.loadState {
        case .idle:               return 0.0
        case .downloading(let p): return p
        case .loading:            return 1.0
        case .ready:              return 1.0
        case .failed:             return 0.0
        }
    }

    private var statusLabel: String {
        switch service.loadState {
        case .idle:               return "Preparing…"
        case .downloading(let p): return "Downloading Qwen3 4B… \(Int(p * 100))%"
        case .loading:            return "Loading model into memory…"
        case .ready:              return "Ready!"
        case .failed(let msg):    return msg
        }
    }

    var body: some View {
        VStack(spacing: 44) {
            // Branding
            VStack(spacing: 10) {
                Image("KerjaInMascot")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                Text("kerjaIn")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color.inkPrimary)
                Text("Setting up AI model for first use")
                    .font(.system(size: 14))
                    .foregroundStyle(Color.inkSecondary)
            }

            // Walking mascot + progress bar
            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let w = geo.size.width
                        let h = geo.size.height
                        let filledW = w * animatedProgress
                        let cx = min(max(filledW, mascotW / 2), w - mascotW / 2)
                        Image(frames[frameIndex])
                            .resizable()
                            .scaledToFit()
                            .frame(width: mascotW, height: mascotH)
                            .position(x: cx, y: h - mascotH / 2 + bobOffset)
                    }
                    .frame(height: mascotH + bobAmp + 4)

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

                Text(statusLabel)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.inkSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .id(statusLabel)
                    .animation(.easeInOut(duration: 0.2), value: statusLabel)
            }

            // Retry button only on failure
            if case .failed = service.loadState {
                Button("Retry Download") {
                    Task { await service.loadSelectedModel() }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.inkPrimary)
            }
        }
        .padding(60)
        .frame(width: 480)
        .background(Color.appBackground)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.6)) {
                animatedProgress = targetProgress
            }
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
