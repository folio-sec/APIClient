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

    public enum Parameters {
        case query([String: Any?])
        case form([String: String?])
        case json(Data?)

        public init(_ raw: [String: Any?]) {
            self = .query(raw)
        }

        public init(_ raw: [String: String?]) {
            self = .form(raw)
        }

        public init<T>(_ raw: T) where T: Encodable {
            let encoder = JSONEncoder()
            encoder.dataEncodingStrategy = .base64
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(raw) {
                self = .json(data)
            } else {
                self = .json(nil)
            }
        }
    }
}
