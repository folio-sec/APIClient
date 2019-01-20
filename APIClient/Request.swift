import Foundation

public struct Request<ResponseBody> {
    public let endpoint: String
    public let method: String
    public let parameters: Parameters?

    public init(endpoint: String, method: String, parameters: Parameters? = nil) {
        self.endpoint = endpoint
        self.method = method
        self.parameters = parameters
    }
}

public enum Parameters {
    case form([String: String?])
    case json(AnyEncodable)

    public init(_ raw: [String: String?]) {
        self = .form(raw)
    }

    public init<T>(_ raw: T) where T: Encodable {
        self = .json(AnyEncodable(raw))
    }
}

public struct AnyEncodable: Encodable {
    var _encodeFunc: (Encoder) throws -> Void

    init(_ encodable: Encodable) {
        func _encode(to encoder: Encoder) throws {
            try encodable.encode(to: encoder)
        }
        self._encodeFunc = _encode
    }

    public func encode(to encoder: Encoder) throws {
        try _encodeFunc(encoder)
    }
}
