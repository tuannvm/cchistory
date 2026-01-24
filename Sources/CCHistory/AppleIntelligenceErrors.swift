import Foundation

// MARK: - Request Errors

/// Errors that can occur when parsing a request
public enum RequestError: LocalizedError, Sendable {
    case nonConformingBody
    case invalidMessageRole(String)
    case invalidModel(String)
    case noPromptOrMessages
    case unsupportedFeature(String)

    public var errorDescription: String? {
        switch self {
        case .nonConformingBody:
            return "Request body does not conform to expected standard."
        case .invalidMessageRole(let role):
            return "An invalid message role was given: '\(role)'. These must be either 'system', 'user', or 'assistant'."
        case .invalidModel(let model):
            return "The requested model '\(model)' does not exist."
        case .noPromptOrMessages:
            return "One of `messages` or `prompt` is required."
        case .unsupportedFeature(let feature):
            return "The feature '\(feature)' is not yet supported."
        }
    }
}

// MARK: - Response Errors

/// Errors that can occur during response generation
public enum ResponseError: LocalizedError, Sendable {
    case serializationError(String)
    case moderationError
    case generationError(String)
    case guardrailViolation

    public var errorDescription: String? {
        switch self {
        case .serializationError(let description):
            return "Failed to serialize response: \(description)"
        case .moderationError:
            return "Your chosen model requires moderation and your input was flagged."
        case .generationError(let message):
            return "Generation error: \(message)"
        case .guardrailViolation:
            return "Content was blocked by guardrail policies."
        }
    }

    public var failureReason: String? {
        errorDescription
    }
}
