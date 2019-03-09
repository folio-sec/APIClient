import Foundation

public class Client {
    public let baseURL: URL
    public let headers: [AnyHashable: Any]

    public var dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601
    public var dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64

    public var authenticator: Authenticating?
    public var interceptors = [Intercepting]()

    private let session: URLSession
    private let queue = DispatchQueue.init(label: "com.folio-sec.api-client", qos: .userInitiated)
    private let taskExecutor = TaskExecutor()

    private var pendingRequests = [PendingRequest]()
    private var isRetrying = false

    public init(baseURL: URL, headers: [AnyHashable: Any] = [:]) {
        self.baseURL = baseURL
        self.headers = headers

        let config = URLSessionConfiguration.ephemeral
        config.httpAdditionalHeaders = headers

        session = URLSession(configuration: config)
    }

    public func cancel(taskIdentifier: Int) {
        taskExecutor.cancel(taskIdentifier: taskIdentifier)
    }

    public func cancelAll() {
        taskExecutor.cancelAll()
    }

    public func perform<ResponseBody>(request: Request<ResponseBody>, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.perform(request: request.makeURLRequest(baseURL: self.baseURL), completion: completion)
        }
    }

    private func perform<ResponseBody>(request: URLRequest, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) {
        interceptRequest(interceptors: self.interceptors, request: request) { [weak self] (request) in
            guard let self = self else { return }

            let task = self.session.dataTask(with: request) { [weak self] (data, response, error) in
                guard let self = self else { return }

                self.queue.async { [weak self] in
                    guard let self = self else { return }

                    self.interceptResponse(interceptors: self.interceptors, request: request, response: response, data: data, error: error) { [weak self] (response, data, error) in
                        guard let self = self else { return }

                        self.queue.async { [weak self] in
                            guard let self = self else { return }
                            self.handleResponse(request: request, response: response, data: data, error: error, completion: completion)
                        }
                    }
                    self.taskExecutor.startPendingTasks()
                }
            }
            self.taskExecutor.push(Task(sessionTask: task))
        }
    }

    private func handleResponse<ResponseBody>(request: URLRequest, response: URLResponse?, data: Data?, error: Error?, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) {
        if let error = error {
            completion(.failure(.networkError(error)))
            return
        }
        if let response = response as? HTTPURLResponse, let data = data {
            let statusCode = response.statusCode
            switch statusCode {
            case 100...199: // Informational
                break
            case 200...299: // Success
                handleDecodableResponse(response: response, data: data, completion: completion)
            case 300...399: // Redirection
                break
            case 400...499: // Client Error
                if let authenticator = self.authenticator {
                    if !isRetrying {
                        isRetrying = true

                        self.authenticate(authenticator: authenticator, request: request, response: response, data: data) { [weak self] (result) in
                            guard let self = self else { return }

                            self.queue.async { [weak self] in
                                guard let self = self else { return }

                                switch result {
                                case .success(let request):
                                    self.perform(request: request, completion: completion)
                                    self.retryPendingRequests()
                                case .failure(let error):
                                    completion(.failure(error))
                                    self.failPendingRequests(error)
                                case .cancel:
                                    let error = Failure.responseError(statusCode, response.allHeaderFields, data)
                                    completion(.failure(error))
                                    self.cancelPendingRequests(error)
                                }

                                self.isRetrying = false
                            }
                        }
                    } else {
                        let pendingRequest = PendingRequest(request: request,
                                                            retry: { self.perform(request: request, completion: completion) },
                                                            fail: { completion(.failure($0)) },
                                                            cancel: { _ in completion(.failure(.responseError(statusCode, response.allHeaderFields, data))) })
                        pendingRequests.append(pendingRequest)
                    }
                } else {
                    completion(.failure(.responseError(statusCode, response.allHeaderFields, data)))
                }
            case 500...599: // Server Error
                completion(.failure(.responseError(statusCode, response.allHeaderFields, data)))
            default:
                break
            }
        }
    }

    private func handleDecodableResponse(response: HTTPURLResponse, data: Data, completion: @escaping (Result<Response<Void>, Failure>) -> Void) {
        completion(.success(Response(statusCode: response.statusCode, headers: response.allHeaderFields, body: ())))
    }

    private func handleDecodableResponse<ResponseBody>(response: HTTPURLResponse, data: Data, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) where ResponseBody: Decodable {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = dateDecodingStrategy
        decoder.dataDecodingStrategy = dataDecodingStrategy
        do {
            let responseBody = try decoder.decode(ResponseBody.self, from: data)
            completion(.success(Response(statusCode: response.statusCode, headers: response.allHeaderFields, body: responseBody)))
        } catch {
            completion(.failure(.decodingError(error, response.statusCode, response.allHeaderFields, data)))
        }
    }

    private func handleDecodableResponse<ResponseBody>(response: HTTPURLResponse, data: Data, completion: @escaping (Result<Response<ResponseBody>, Failure>) -> Void) {
        fatalError("unexpected response type")
    }

    private func retryPendingRequests() {
        for request in pendingRequests {
            request.retry()
        }
        pendingRequests.removeAll()
    }

    private func failPendingRequests(_ error: Failure) {
        for request in pendingRequests {
            request.fail(error)
        }
        pendingRequests.removeAll()
    }

    private func cancelPendingRequests(_ error: Failure) {
        for request in pendingRequests {
            request.cancel(error)
        }
        pendingRequests.removeAll()
    }

    private func interceptRequest(interceptors: [Intercepting], request: URLRequest, completion: @escaping (URLRequest) -> Void) {
        completion(interceptors.reduce(request) { $1.intercept(client: self, request: $0) })
    }

    private func interceptResponse(interceptors: [Intercepting], request: URLRequest, response: URLResponse?, data: Data?, error: Error?, completion: @escaping (URLResponse?, Data?, Error?) -> Void) {
        let (response, data, error) = interceptors.reduce((response, data, error)) { $1.intercept(client: self, request: request, response: $0.0, data: $0.1, error: $0.2) }
        completion(response, data, error)
    }

    private func authenticate(authenticator: Authenticating, request: URLRequest, response: HTTPURLResponse, data: Data?, completion: @escaping (AuthenticationResult) -> Void) {
        let client = Client(baseURL: baseURL, headers: headers)
        client.interceptors = interceptors
        authenticator.authenticate(client: client, request: request, response: response, data: data) {
            completion($0)
            withExtendedLifetime(client) {}
        }
    }
}

private struct PendingRequest {
    let request: URLRequest
    let retry: () -> Void
    let fail: (Failure) -> Void
    let cancel: (Failure) -> Void
}

private class TaskExecutor {
    private var tasks = [Task]()
    private var runningTasks = [Int: Task]()
    private let maxConcurrentTasks = 4

    func push(_ task: Task) {
        if let index = tasks.firstIndex(of: task) {
            tasks.remove(at: index)
        }
        tasks.append(task)
        startPendingTasks()
    }

    func cancel(taskIdentifier: Int) {
        if let task = runningTasks[taskIdentifier] {
            task.sessionTask.cancel()
            runningTasks[taskIdentifier] = nil
        }
    }

    func cancelAll() {
        (tasks + runningTasks.values).forEach { $0.sessionTask.cancel() }
        tasks.removeAll()
        runningTasks.removeAll()
    }

    func startPendingTasks() {
        for runningTask in runningTasks {
            switch runningTask.value.sessionTask.state {
            case .running, .suspended, .canceling:
                break
            case .completed:
                runningTasks[runningTask.key] = nil
            }
        }
        while tasks.count > 0 && runningTasks.count <= maxConcurrentTasks {
            let task = tasks.removeLast()
            task.sessionTask.resume()
            runningTasks[task.taskIdentifier] = task
        }
    }
}

private class Task: Hashable {
    let sessionTask: URLSessionTask
    let taskIdentifier: Int

    init(sessionTask: URLSessionTask) {
        self.sessionTask = sessionTask
        self.taskIdentifier = sessionTask.taskIdentifier
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(taskIdentifier)
    }

    static func == (lhs: Task, rhs: Task) -> Bool {
        return lhs.taskIdentifier == rhs.taskIdentifier
    }
}
