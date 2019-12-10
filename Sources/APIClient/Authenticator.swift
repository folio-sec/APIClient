import Foundation

public protocol Authenticating {
    func shouldRetry(client: Client, request: URLRequest, response: HTTPURLResponse, data: Data?) -> Bool
    func authenticate(client: Client, request: URLRequest, response: HTTPURLResponse, data: Data?, completion: @escaping (AuthenticationResult) -> Void)
}

public enum AuthenticationResult {
    case success(URLRequest)
    case failure(Failure)
    case cancel
}
