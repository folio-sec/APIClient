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
        case multipart([String: Any?])
        case json(Data?)

        public init(_ raw: [String: Any?]) {
            self = .query(raw)
        }

        public init(_ raw: [String: String?]) {
            self = .form(raw)
        }

        public init<T: Encodable>(_ raw: T, dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .iso8601, dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64) {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = dateEncodingStrategy
            encoder.dataEncodingStrategy = dataEncodingStrategy
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
                    var queryItems = [URLQueryItem]()
                    for (key, value) in raw {
                        switch value {
                        case let values as [Any?]:
                            queryItems.append(contentsOf: values.compactMap {
                                if let value = $0 {
                                    return URLQueryItem(name: key, value: "\(value)".addingPercentEncoding(withAllowedCharacters: .alphanumerics))
                                }
                                return nil
                            })
                        case let value?:
                            queryItems.append(URLQueryItem(name: key, value: "\(value)".addingPercentEncoding(withAllowedCharacters: .alphanumerics)))
                        default:
                            break
                        }
                    }
                    if #available(iOS 11.0, *) {
                        components.percentEncodedQueryItems = queryItems
                    } else {
                        components.queryItems = queryItems
                    }
                    request.url = components.url
                }
            case .form(let raw):
                var components = URLComponents()
                components.queryItems = raw.compactMap {
                    if let value = $0.value {
                        return URLQueryItem(name: $0.key, value: value.addingPercentEncoding(withAllowedCharacters: .alphanumerics))
                    }
                    return nil
                }

                if let query = components.query {
                    request.addValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    request.httpBody = query.data(using: .utf8)
                }
            case .multipart(let raw):
                let boundaryIdentifier = UUID().uuidString

                let boundary = "--\(boundaryIdentifier)\r\n".data(using: .utf8)!
                var body = Data()

                for multipartFormData in raw.compactMap({ data in data.value.map { MultipartFormData(name: data.key, data: $0) } }) {
                    body.append(boundary)
                    body.append(multipartFormData.encode())
                }
                body.append("--\(boundaryIdentifier)--\r\n".data(using: .utf8)!)

                request.addValue("multipart/form-data; boundary=\(boundaryIdentifier)", forHTTPHeaderField: "Content-Type")
                request.httpBody = body
            case .json(let data):
                request.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                request.httpBody = data
            }
        }

        return request
    }

    struct MultipartFormData {
        let name: String
        let data: Any

        func encode() -> Data {
            var encoded = Data()

            encoded.append(#"Content-Disposition: form-data; name="\#(name)""#.data(using: .utf8)!)
            if let url = data as? URL {
                encoded.append(#"; filename="\#(url.lastPathComponent)""#.data(using: .utf8)!)
            }
            encoded.append("\r\n".data(using: .utf8)!)

            let body = encodeBody()
            encoded.append("Content-Length: \(body.count)\r\n\r\n".data(using: .utf8)!)

            encoded.append(body)
            encoded.append("\r\n".data(using: .utf8)!)
            return encoded
        }

        func encodeBody() -> Data {
            switch data {
            case let number as Int:
                if let body = "\(number)".data(using: .utf8) {
                    return body
                }
            case let string as String:
                if let body = string.data(using: .utf8) {
                    return body
                }
            case let url as URL:
                if let body = try? Data(contentsOf: url) {
                    return body
                }
            case let data as Data:
                return data
            default:
                if let body = "\(data)".data(using: .utf8) {
                    return body
                }
            }

            return Data()
        }
    }
}
