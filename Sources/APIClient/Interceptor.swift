import Foundation

public protocol Intercepting {
    func intercept(client: Client, request: URLRequest) -> URLRequest
    func intercept(client: Client, request: URLRequest, response: URLResponse?, data: Data?, error: Error?) -> (URLResponse?, Data?, Error?)
}

public extension Intercepting {
    func intercept(client: Client, request: URLRequest) -> URLRequest {
        return request
    }
    
    func intercept(client: Client, request: URLRequest, response: URLResponse?, data: Data?, error: Error?) -> (URLResponse?, Data?, Error?) {
        return (response, data, error)
    }
}
