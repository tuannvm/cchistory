import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Language Model Configuration

/// Available language models with their guardrail settings
public enum AppleLanguageModel: String, Sendable {
    case base
    case permissive

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    var systemModel: SystemLanguageModel {
        switch self {
        case .base:
            return .default
        case .permissive:
            return SystemLanguageModel(guardrails: .permissiveContentTransformations)
        }
    }
    #endif
}

/// Finish reason for generation completion
public enum FinishReason: String, Sendable {
    case stop = "stop"
    case length = "length"
    case contentFilter = "content_filter"
    case error = "error"
}

// MARK: - Session Response

/// Response from an Apple Intelligence session
public struct SessionResponse: Sendable {
    public var content: String?
    public var finishReason: FinishReason?

    public init(content: String? = nil, finishReason: FinishReason? = nil) {
        self.content = content
        self.finishReason = finishReason
    }
}

// MARK: - Apple Intelligence Session

/// Manages a session with Apple's on-device Foundation Models
public final class AppleIntelligenceSession: @unchecked Sendable {

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private var model: SystemLanguageModel
    #endif

    private let modelName: String
    private let isChat: Bool
    private let prompt: String
    private let toStream: Bool
    private let responseFormat: ResponseFormat?

    // Generation options
    private let temperature: Double?
    private let maxTokens: Int?
    private let topP: Double?
    private let topK: Int?
    private let seed: UInt64?

    /// Create a new session from a chat completion request
    /// - Parameter request: The chat completion request
    /// - Returns: An initialized session, or nil if Foundation Models is not available
    public init?(from request: ChatCompletionRequest) throws {
        // Check if FoundationModels is available
        #if !canImport(FoundationModels)
            throw RequestError.unsupportedFeature("FoundationModels framework is not available on this system")
        #else
            guard #available(macOS 26.0, *) else {
                throw RequestError.unsupportedFeature("Apple Intelligence requires macOS 26.0 or later")
            }

            // Get model
            self.modelName = request.model ?? "base"
            guard let modelEnum = AppleLanguageModel(rawValue: modelName) else {
                throw RequestError.invalidModel(modelName)
            }
            self.model = modelEnum.systemModel

            // Get prompt text
            if let messages = request.messages, !messages.isEmpty {
                self.isChat = true
                self.prompt = messages.last?.content ?? ""
            } else if let promptText = request.prompt {
                self.isChat = false
                self.prompt = promptText
            } else {
                throw RequestError.noPromptOrMessages
            }

            // Store options
            self.toStream = request.stream ?? false
            self.temperature = request.temperature
            self.maxTokens = request.max_tokens
            self.topP = request.top_p
            self.topK = request.top_k
            self.seed = request.seed
            self.responseFormat = request.response_format
        #endif
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private var generationOptions: GenerationOptions {
        // Build sampling mode
        var samplingMode: GenerationOptions.SamplingMode?
        if let threshold = topP {
            samplingMode = .random(probabilityThreshold: threshold, seed: seed)
        } else if let cutoff = topK {
            samplingMode = .random(top: cutoff, seed: seed)
        }

        return GenerationOptions(
            sampling: samplingMode,
            temperature: temperature,
            maximumResponseTokens: maxTokens
        )
    }
    #endif

    /// Get a non-streaming response
    /// - Returns: The session response
    public func getResponse() async throws -> SessionResponse {
        #if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            throw RequestError.unsupportedFeature("Apple Intelligence requires macOS 26.0 or later")
        }

        // Create session and prompt
        let prompt = Prompt(self.prompt)
        let session = LanguageModelSession(model: model)

        var response = SessionResponse()

        do {
            // For now, we only support simple text generation
            // Structured output would require building a GenerationSchema
            let result = try await session.respond(to: prompt, options: generationOptions)
            response.content = result.content
            response.finishReason = .stop
        } catch {
            response = handleGenerationError(error)
        }

        return response
        #else
        throw RequestError.unsupportedFeature("FoundationModels framework is not available")
        #endif
    }

    /// Get a streaming response
    /// - Returns: An async stream of session responses
    public func streamResponses() -> AsyncStream<SessionResponse> {
        return AsyncStream { continuation in
            Task {
                #if canImport(FoundationModels)
                guard #available(macOS 26.0, *) else {
                    continuation.finish()
                    return
                }

                do {
                    // Create session and prompt
                    let prompt = Prompt(self.prompt)
                    let session = LanguageModelSession(model: model)

                    // Get the streaming response
                    let stream = session.streamResponse(to: prompt, options: generationOptions)

                    for try await snapshot in stream {
                        let response = SessionResponse(
                            content: snapshot.content,
                            finishReason: nil // Will be set to .stop when loop completes
                        )
                        continuation.yield(response)
                    }

                    // Send final completion message
                    continuation.yield(SessionResponse(content: "", finishReason: .stop))
                    continuation.finish()
                } catch {
                    let errorResponse = handleGenerationError(error)
                    continuation.yield(errorResponse)
                    continuation.finish()
                }
                #else
                continuation.finish()
                #endif
            }
        }
    }

    #if canImport(FoundationModels)
    @available(macOS 26.0, *)
    private func handleGenerationError(_ error: any Error) -> SessionResponse {
        if let genError = error as? LanguageModelSession.GenerationError {
            switch genError {
            case .exceededContextWindowSize:
                return SessionResponse(content: "Error: Exceeded context window size.", finishReason: .length)
            case .guardrailViolation:
                return SessionResponse(content: "Error: Guardrail violation.", finishReason: .contentFilter)
            default:
                return SessionResponse(content: "Error: Generation error (\(genError))", finishReason: .error)
            }
        } else {
            return SessionResponse(content: "Error: \(error.localizedDescription)", finishReason: .error)
        }
    }
    #endif
}

// MARK: - Response Builder

/// Builds chat completion responses from Apple Intelligence sessions
public enum AppleIntelligenceResponseBuilder {

    /// Build a standard (non-streaming) chat completion response
    public static func buildResponse(
        from sessionResponse: SessionResponse,
        model: String
    ) -> ChatCompletionResponse {
        let choice = Choice(
            finish_reason: sessionResponse.finishReason?.rawValue,
            native_finish_reason: sessionResponse.finishReason?.rawValue,
            message: Message(role: "assistant", content: sessionResponse.content ?? "")
        )

        return ChatCompletionResponse(
            model: model,
            choices: [choice]
        )
    }

    /// Build a streaming chunk response
    public static func buildChunk(
        from sessionResponse: SessionResponse,
        model: String,
        id: String = "gen-\(UUID().uuidString)"
    ) -> ChatCompletionChunk {
        let choice = Choice(
            finish_reason: sessionResponse.finishReason?.rawValue,
            native_finish_reason: sessionResponse.finishReason?.rawValue,
            delta: sessionResponse.content != nil ? Message(role: "assistant", content: sessionResponse.content!) : nil
        )

        return ChatCompletionChunk(
            id: id,
            created: Int64(Date().timeIntervalSince1970),
            model: model,
            choices: [choice]
        )
    }

    /// Build SSE data string for a chunk
    public static func buildSSEData(from chunk: ChatCompletionChunk) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(chunk)
        guard let jsonString = String(data: data, encoding: .utf8) else {
            throw ResponseError.serializationError("Failed to encode chunk as JSON")
        }
        return "data: \(jsonString)\n\n"
    }

    /// Build the SSE termination string
    public static var sseTermination: String {
        return "data: [DONE]\n\n"
    }
}

// MARK: - Availability Check

/// Check if Apple Intelligence is available on this system
public var isAppleIntelligenceAvailable: Bool {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        return true
    } else {
        return false
    }
    #else
    return false
    #endif
}

/// Get a description of why Apple Intelligence is not available
public var appleIntelligenceAvailabilityDescription: String {
    #if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
        return "Available"
    } else {
        return "Requires macOS 26.0 or later with Apple Intelligence"
    }
    #else
    return "FoundationModels framework is not available"
    #endif
}
