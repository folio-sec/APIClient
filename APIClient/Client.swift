import Foundation

public class Client {
    public let baseURL: URL
    private let session: URLSession
    public private(set) var interceptors = [Intercepting]()

    private let queue = DispatchQueue.init(label: "com.folio-sec.api-client", qos: .userInitiated)

    public init(baseURL: URL, headers: [AnyHashable : Any] = [:]) {
        self.baseURL = baseURL

        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = headers

        session = URLSession(configuration: config)
    }

    public func add(interceptor: Intercepting) {
        interceptors.append(interceptor)
    }

    public func perform<ResponseBody>(request: Request<ResponseBody>, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) where ResponseBody: Decodable {
        let url = baseURL.appendingPathComponent(request.endpoint)

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.description

        if let parameters = request.parameters {
            switch parameters {
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
            case .json(let raw):
                urlRequest.addValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                let encoder = JSONEncoder()
                if let data = try? encoder.encode(raw) {
                    urlRequest.httpBody = data
                }
            }
        }

        intercept(interceptors: self.interceptors, request: urlRequest, response: nil) { [weak self] in
            guard let self = self else { return }

            switch $0 {
            case .success(let request):
                self.perform(request: request, completion: completion)
            case .failure(let cause):
                completion(.failure(cause))
            }
        }
    }

    private func perform<ResponseBody>(request: URLRequest, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) where ResponseBody: Decodable {
        let task = session.dataTask(with: request) { [weak self] (data, response, error) in
            guard let self = self else { return }

            if let error = error {
                completion(.failure(.cause(error)))
            }
            if let response = response as? HTTPURLResponse, let data = data {
                let statusCode = response.statusCode
                switch statusCode {
                case 200:
                    let decoder = JSONDecoder()
                    do {
                        let responseBody = try decoder.decode(ResponseBody.self, from: data)
                        completion(.success(Response(statusCode: statusCode, headers: response.allHeaderFields, body: responseBody)))
                    } catch (let decodingError) {
                        completion(.failure(.cause(decodingError)))
                    }
                case 401:
                    self.intercept(interceptors: self.interceptors, request: request, response: response) { [weak self] in
                        guard let self = self else { return }

                        switch $0 {
                        case .success(let request):
                            self.perform(request: request, completion: completion)
                        case .failure(let cause):
                            completion(.failure(cause))
                        }
                    }
                default:
                    completion(.failure(Failure.responseError(statusCode, response.allHeaderFields, data)))
                }
            }
        }
        task.resume()
    }

    private func intercept(interceptors: [Intercepting], request: URLRequest, response: URLResponse?, completion: @escaping (Result<URLRequest, Failure>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else {
                completion(.success(request))
                return
            }
            var interceptors = ArraySlice(interceptors)
            if let interceptor = interceptors.popFirst() {
                interceptor.intercept(client: self, request: request, response: response) { [weak self] in
                    guard let self = self else { return }

                    switch $0 {
                    case .success(let request):
                        self.intercept(interceptors: Array(interceptors), request: request, response: response, completion: completion)
                    case .failure(let cause):
                        self.interceptors.removeAll()
                        completion(.failure(cause))
                    }
                }
            } else {
                completion(.success(request))
            }
        }
    }
}
