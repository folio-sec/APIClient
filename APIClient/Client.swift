import Foundation

public class Client {
    public let baseURL: URL
    public let headers: [AnyHashable: Any]

    public var authenticator: Authenticating?
    public var interceptors = [Intercepting]()

    private let session: URLSession
    private let queue = DispatchQueue.init(label: "com.folio-sec.api-client", qos: .userInitiated)

    public init(baseURL: URL, headers: [AnyHashable: Any] = [:]) {
        self.baseURL = baseURL
        self.headers = headers

        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = headers

        session = URLSession(configuration: config)
    }

    public func perform<ResponseBody>(request: Request<ResponseBody>, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) where ResponseBody: Decodable {
        let url = baseURL.appendingPathComponent(request.endpoint)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.description

        if let parameters = request.parameters {
            switch parameters {
            case .query(let raw):
                if var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                    components.queryItems = raw.compactMap {
                        if let value = $0.value {
                            return URLQueryItem(name: $0.key, value: "\(value)")
                        }
                        return nil
                    }
                    urlRequest.url = components.url
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
                    urlRequest.addValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
                    urlRequest.httpBody = query.data(using: .utf8)
                }
            case .json(let data):
                urlRequest.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                urlRequest.httpBody = data
            }
        }

        interceptRequest(interceptors: interceptors, request: urlRequest) { [weak self] (request) in
            guard let self = self else { return }
            self.perform(request: request, completion: completion)
        }
    }

    private func perform<ResponseBody>(request: URLRequest, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) where ResponseBody: Decodable {
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }

            self.interceptResponse(interceptors: self.interceptors, request: request, response: response, data: data, error: error) { (response, data, error) in
                if let error = error {
                    completion(.failure(.cause(error)))
                    return
                }
                if let response = response as? HTTPURLResponse, let data = data {
                    let statusCode = response.statusCode
                    switch statusCode {
                    case 100...199: // Informational
                        break
                    case 200...299: // Success
                        let decoder = JSONDecoder()
                        do {
                            let responseBody = try decoder.decode(ResponseBody.self, from: data)
                            completion(.success(Response(statusCode: statusCode, headers: response.allHeaderFields, body: responseBody)))
                        } catch (let decodingError) {
                            completion(.failure(.cause(decodingError)))
                        }
                    case 300...399: // Redirection
                        break
                    case 400...499: // Client Error
                        if let authenticator = self.authenticator {
                            self.authenticate(authenticator: authenticator, request: request, response: response, data: data) { [weak self] in
                                guard let self = self else { return }
                                switch $0 {
                                case .success(let request):
                                    self.perform(request: request, completion: completion)
                                case .failure(let error):
                                    completion(.failure(error))
                                case .cancel:
                                    completion(.failure(Failure.responseError(statusCode, response.allHeaderFields, data)))
                                }
                            }
                        } else {
                            completion(.failure(Failure.responseError(statusCode, response.allHeaderFields, data)))
                        }
                    case 500...599: // Server Error
                        completion(.failure(Failure.responseError(statusCode, response.allHeaderFields, data)))
                    default:
                        break
                    }
                }
            }
        }
        task.resume()
    }

    private func interceptRequest(interceptors: [Intercepting], request: URLRequest, completion: @escaping (URLRequest) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {return }
            completion(interceptors.reduce(request) { $1.intercept(client: self, request: $0) })
        }
    }

    private func interceptResponse(interceptors: [Intercepting], request: URLRequest, response: URLResponse?, data: Data?, error: Error?, completion: @escaping (URLResponse?, Data?, Error?) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            let (response, data, error) = interceptors.reduce((response, data, error)) { $1.intercept(client: self, request: request, response: $0.0, data: $0.1, error: $0.2) }
            completion(response, data, error)
        }
    }

    private func authenticate(authenticator: Authenticating, request: URLRequest, response: HTTPURLResponse, data: Data?, completion: @escaping (AuthenticationResult) -> Void) {
        authenticator.authenticate(client: self, request: request, response: response, data: data, completion: completion)
    }
}
