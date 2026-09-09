import Foundation
import MLXLLM
import MLXLMCommon
import Observation

// MARK: - Model catalogue

enum MLXModel: String, CaseIterable, Identifiable {
    case llama3_2_1B
    case llama3_2_3B
    case mistral7B
    case qwen2_5_1_5B
    case qwen2_5_7B
    case qwen3_4B

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .llama3_2_1B:  return "Llama 3.2 1B"
        case .llama3_2_3B:  return "Llama 3.2 3B"
        case .mistral7B:    return "Mistral 7B"
        case .qwen2_5_1_5B: return "Qwen 2.5 1.5B"
        case .qwen2_5_7B:   return "Qwen 2.5 7B"
        case .qwen3_4B:     return "Qwen3 4B"
        }
    }

    var sizeLabel: String {
        switch self {
        case .llama3_2_1B:  return "~700 MB"
        case .llama3_2_3B:  return "~1.8 GB"
        case .mistral7B:    return "~4.1 GB"
        case .qwen2_5_1_5B: return "~1.0 GB"
        case .qwen2_5_7B:   return "~4.3 GB"
        case .qwen3_4B:     return "~2.5 GB"
        }
    }

    var configuration: ModelConfiguration {
        switch self {
        case .llama3_2_1B:  return LLMRegistry.llama3_2_1B_4bit
        case .llama3_2_3B:  return LLMRegistry.llama3_2_3B_4bit
        case .mistral7B:    return LLMRegistry.mistral7B4bit
        case .qwen2_5_1_5B: return LLMRegistry.qwen2_5_1_5b
        case .qwen2_5_7B:   return LLMRegistry.qwen2_5_7b
        case .qwen3_4B:     return LLMRegistry.qwen3_4b_4bit
        }
    }
}

// MARK: - Service

@Observable
@MainActor
final class MLXInferenceService {
    static let shared = MLXInferenceService()

    enum LoadState: Equatable {
        case idle
        case downloading(Double)
        case loading
        case ready
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }

        var statusLabel: String {
            switch self {
            case .idle:                return "Not loaded"
            case .downloading(let p):  return "Downloading \(Int(p * 100))%…"
            case .loading:             return "Loading into memory…"
            case .ready:               return "Ready"
            case .failed(let msg):     return "Error: \(msg)"
            }
        }
    }

    var selectedModel: MLXModel = .llama3_2_3B
    var loadState: LoadState = .idle
    private var container: ModelContainer?
    private var loadedModel: MLXModel?

    private init() {}

    var isReady: Bool { loadState.isReady }

    // Load the currently selected model (no-op if already loaded).
    func loadSelectedModel() async {
        let model = selectedModel
        if loadedModel == model, isReady { return }

        container = nil
        loadedModel = nil
        loadState = .downloading(0)

        do {
            let loaded = try await loadModelContainer(
                configuration: model.configuration
            ) { [weak self] progress in
                let fraction = progress.fractionCompleted
                Task { @MainActor [weak self] in
                    guard let self, !self.loadState.isReady else { return }
                    self.loadState = .downloading(fraction)
                }
            }
            loadState = .loading
            container = loaded
            loadedModel = model
            loadState = .ready
        } catch {
            loadState = .failed(error.localizedDescription)
        }
    }

    // Switch to a different model (unloads the current one).
    func switchModel(to model: MLXModel) {
        guard model != loadedModel else { return }
        container = nil
        loadedModel = nil
        loadState = .idle
        selectedModel = model
    }

    // Generate a completion. maxTokens prevents runaway generation.
    // Qwen3 thinking mode is disabled via /no_think to skip internal reasoning tokens.
    func generate(system: String, prompt: String, maxTokens: Int = 700) async throws -> String {
        guard let container else {
            throw InferenceError.modelNotLoaded
        }
        let finalPrompt: String
        if loadedModel == .qwen3_4B {
            finalPrompt = "/no_think\n\n\(prompt)"
        } else {
            finalPrompt = prompt
        }
        let session = ChatSession(
            container,
            instructions: system,
            generateParameters: GenerateParameters(maxTokens: maxTokens, temperature: 0.1)
        )
        return try await session.respond(to: finalPrompt)
    }

    // MARK: - JSON helpers

    // Strips thinking blocks, markdown fences, then extracts the outermost balanced JSON object.
    static func extractJSON(from text: String) -> String {
        var s = text

        // Strip Qwen3 / o1-style thinking blocks: <think>…</think>
        var stripped = s
        while let open = stripped.range(of: "<think>", options: .caseInsensitive),
              let close = stripped.range(of: "</think>", options: .caseInsensitive),
              open.lowerBound <= close.lowerBound {
            stripped.removeSubrange(open.lowerBound..<close.upperBound)
        }
        s = stripped

        // Strip markdown fences
        for fence in ["```json", "```"] { s = s.replacingOccurrences(of: fence, with: "") }
        s = s.trimmingCharacters(in: .whitespacesAndNewlines)

        // Find first { and extract the balanced JSON object via brace-depth counting
        guard let startIdx = s.firstIndex(of: "{") else { return s }

        var depth = 0
        var inString = false
        var escaped = false

        for idx in s[startIdx...].indices {
            let c = s[idx]
            if escaped               { escaped = false; continue }
            if c == "\\" && inString { escaped = true;  continue }
            if c == "\""             { inString.toggle(); continue }
            if inString              { continue }
            if c == "{"              { depth += 1 }
            if c == "}" {
                depth -= 1
                if depth == 0 { return String(s[startIdx...idx]) }
            }
        }
        return String(s[startIdx...])
    }

    static func decode<T: Decodable>(_ type: T.Type, from text: String) throws -> T {
        let json = extractJSON(from: text)
        guard let data = json.data(using: .utf8) else {
            throw InferenceError.jsonParsingFailed(String(json.prefix(400)))
        }
        // Try camelCase first, then snake_case (models vary in naming convention)
        let decoders: [JSONDecoder] = {
            let camel = JSONDecoder()
            let snake = JSONDecoder()
            snake.keyDecodingStrategy = .convertFromSnakeCase
            return [camel, snake]
        }()
        for decoder in decoders {
            if let result = try? decoder.decode(type, from: data) { return result }
        }
        throw InferenceError.jsonParsingFailed(String(json.prefix(400)))
    }

    // MARK: - Errors

    enum InferenceError: LocalizedError {
        case modelNotLoaded
        case jsonParsingFailed(String)

        var errorDescription: String? {
            switch self {
            case .modelNotLoaded:
                return "No model is loaded. Select and load a model first."
            case .jsonParsingFailed(let raw):
                return "Could not parse the model's output as JSON.\nRaw: \(raw)"
            }
        }
    }
}
