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

        public init<T: Encodable>(_ raw: T) {
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

    func makeURLRequest(baseURL: URL) -> URLRequest {
        let url = baseURL.appendingPathComponent(endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = method.description

        if let parameters = parameters {
            switch parameters {
            case .query(let raw):
                if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    components.queryItems = raw.compactMap {
                        if let value = $0.value {
                            return URLQueryItem(name: $0.key, value: "\(value)")
                        }
                        return nil
                    }
                    request.url = components.url
                }
            case .form(let raw):
                var components = URLComponents()
                components.queryItems = raw.compactMap {
                    if let value = $0.value {
                        return URLQueryItem(name: $0.key, value: value)
                    }
                    return nil
                }

                if let query = components.query {
                    request.addValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    request.httpBody = query.data(using: .utf8)
                }
            case .json(let data):
                request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = data
            }
        }

        return request
    }
}
