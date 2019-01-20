import Foundation

public protocol Intercepting {
    func intercept(client: Client, request: URLRequest, response: URLResponse?, completion: @escaping (Result<URLRequest, Failure>) -> Void)
}
