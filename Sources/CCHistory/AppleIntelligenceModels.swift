import Foundation
import Hummingbird

// MARK: - Request Models

/// A single message in a chat completion request
public struct Message: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

/// JSON Schema property types for structured output
public indirect enum JSONSchemaProperty: Codable, Sendable {
    case string(description: String?, enumValues: [String]?)
    case integer(description: String?, minimum: Int?, maximum: Int?)
    case number(description: String?, minimum: Double?, maximum: Double?)
    case boolean(description: String?)
    case array(description: String?, items: JSONSchemaProperty)
    case object(description: String?, properties: [String: JSONSchemaProperty], required: [String]?)

    private enum CodingKeys: String, CodingKey {
        case type, description, `enum`, minimum, maximum, items, properties, required
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        let description = try container.decodeIfPresent(String.self, forKey: .description)

        switch type {
        case "string":
            let enumValues = try container.decodeIfPresent([String].self, forKey: .enum)
            self = .string(description: description, enumValues: enumValues)
        case "integer":
            let minimum = try container.decodeIfPresent(Int.self, forKey: .minimum)
            let maximum = try container.decodeIfPresent(Int.self, forKey: .maximum)
            self = .integer(description: description, minimum: minimum, maximum: maximum)
        case "number":
            let minimum = try container.decodeIfPresent(Double.self, forKey: .minimum)
            let maximum = try container.decodeIfPresent(Double.self, forKey: .maximum)
            self = .number(description: description, minimum: minimum, maximum: maximum)
        case "boolean":
            self = .boolean(description: description)
        case "array":
            let items = try container.decode(JSONSchemaProperty.self, forKey: .items)
            self = .array(description: description, items: items)
        case "object":
            let properties = try container.decode([String: JSONSchemaProperty].self, forKey: .properties)
            let required = try container.decodeIfPresent([String].self, forKey: .required)
            self = .object(description: description, properties: properties, required: required)
        default:
            throw DecodingError.dataCorruptedError(forKey: .type, in: container, debugDescription: "Unsupported type: \(type)")
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let description, let enumValues):
            try container.encode("string", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(enumValues, forKey: .enum)
        case .integer(let description, let minimum, let maximum):
            try container.encode("integer", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)
        case .number(let description, let minimum, let maximum):
            try container.encode("number", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encodeIfPresent(minimum, forKey: .minimum)
            try container.encodeIfPresent(maximum, forKey: .maximum)
        case .boolean(let description):
            try container.encode("boolean", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
        case .array(let description, let items):
            try container.encode("array", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(items, forKey: .items)
        case .object(let description, let properties, let required):
            try container.encode("object", forKey: .type)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(properties, forKey: .properties)
            try container.encodeIfPresent(required, forKey: .required)
        }
    }
}

/// JSON schema for structured output
public struct JSONSchema: Codable, Sendable {
    public let name: String
    public let description: String?
    public let schema: JSONSchemaProperty?
    public let strict: Bool?

    public init(name: String, description: String? = nil, schema: JSONSchemaProperty? = nil, strict: Bool? = nil) {
        self.name = name
        self.description = description
        self.schema = schema
        self.strict = strict
    }
}

/// Response format specification
public struct ResponseFormat: Codable, Sendable {
    public let type: String // "json_schema" or "text"
    public let json_schema: JSONSchema?

    public init(type: String, json_schema: JSONSchema? = nil) {
        self.type = type
        self.json_schema = json_schema
    }
}

/// Chat completion request content
public struct ChatCompletionRequest: Codable, Sendable {
    // Either `messages` or `prompt` is required
    public let messages: [Message]?
    public let prompt: String?

    // If `model` is unspecified, uses the default
    public let model: String?

    // Enable streaming
    public let stream: Bool?

    // Generation options
    public let max_tokens: Int?
    public let temperature: Double?

    // Advanced options
    public let seed: UInt64?
    public let top_p: Double?
    public let top_k: Int?

    // Structured output support
    public let response_format: ResponseFormat?

    public init(
        messages: [Message]? = nil,
        prompt: String? = nil,
        model: String? = nil,
        stream: Bool? = nil,
        max_tokens: Int? = nil,
        temperature: Double? = nil,
        seed: UInt64? = nil,
        top_p: Double? = nil,
        top_k: Int? = nil,
        response_format: ResponseFormat? = nil
    ) {
        self.messages = messages
        self.prompt = prompt
        self.model = model
        self.stream = stream
        self.max_tokens = max_tokens
        self.temperature = temperature
        self.seed = seed
        self.top_p = top_p
        self.top_k = top_k
        self.response_format = response_format
    }
}

// MARK: - Response Models

/// Model information
public struct Model: Codable, Sendable {
    public let object: String
    public let id: String

    public init(id: String, object: String = "model") {
        self.id = id
        self.object = object
    }
}

/// Models list response
public struct ModelsResponse: ResponseCodable, Sendable {
    public let object: String
    public let data: [Model]

    public init(data: [Model], object: String = "list") {
        self.data = data
        self.object = object
    }
}

/// Chat completion choice
public struct Choice: Codable, Sendable {
    public let finish_reason: String?
    public let native_finish_reason: String?
    public let message: Message?
    public let delta: Message?
    public let text: String?

    public init(
        finish_reason: String? = nil,
        native_finish_reason: String? = nil,
        message: Message? = nil,
        delta: Message? = nil,
        text: String? = nil
    ) {
        self.finish_reason = finish_reason
        self.native_finish_reason = native_finish_reason
        self.message = message
        self.delta = delta
        self.text = text
    }
}

/// Chat completion response
public struct ChatCompletionResponse: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int64
    public let model: String
    public let choices: [Choice]

    public init(
        id: String = "gen-\(UUID().uuidString)",
        object: String = "chat.completion",
        created: Int64 = Int64(Date().timeIntervalSince1970),
        model: String,
        choices: [Choice]
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
    }

    /// Create a streaming chunk response
    public static func chunk(model: String, content: String?, finishReason: String? = nil) -> ChatCompletionResponse {
        return ChatCompletionResponse(
            object: "chat.completion.chunk",
            model: model,
            choices: [
                Choice(
                    finish_reason: finishReason,
                    native_finish_reason: finishReason,
                    delta: content != nil ? Message(role: "assistant", content: content!) : nil
                )
            ]
        )
    }
}

/// Chat completion chunk for streaming
public struct ChatCompletionChunk: Codable, Sendable {
    public let id: String
    public let object: String
    public let created: Int64
    public let model: String
    public let choices: [Choice]

    public init(
        id: String,
        object: String = "chat.completion.chunk",
        created: Int64,
        model: String,
        choices: [Choice]
    ) {
        self.id = id
        self.object = object
        self.created = created
        self.model = model
        self.choices = choices
    }
}
