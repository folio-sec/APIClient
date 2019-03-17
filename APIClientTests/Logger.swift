import Foundation
import APIClient

public struct Logger: Intercepting {
    public init() {}

    public func intercept(client: Client, request: URLRequest) -> URLRequest {
        print("\(requestToCurl(client: client, request: request))")
        return request
    }

    // swiftlint:disable large_tuple
    public func intercept(client: Client, request: URLRequest, response: URLResponse?, data: Data?, error: Error?) -> (URLResponse?, Data?, Error?) {
        if let response = response as? HTTPURLResponse {
            let path = request.url?.path ?? ""
            print("\(request.httpMethod?.uppercased() ?? "") \(path) \(response.statusCode)")
        } else if let error = error {
            print("\(error)")
        }
        return (response, data, error)
    }

    private func requestToCurl(client: Client, request: URLRequest) -> String {
        guard let url = request.url else { return "" }

        var baseCommand = "curl \(url.absoluteString)"
        if request.httpMethod == "HEAD" {
            baseCommand += " --head"
        }
        var command = [baseCommand]
        if let method = request.httpMethod, method != "GET" && method != "HEAD" {
            command.append("-X \(method)")
        }
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in client.headers {
                if let key = key as? String, key != "Cookie" {
                    command.append("-H '\(key): \(value)'")
                }
            }
            for (key, value) in headers where key != "Cookie" {
                command.append("-H '\(key): \(value)'")
            }
        }
        if let data = request.httpBody, let body = String(data: data, encoding: .utf8) {
            command.append("-d '\(body)'")
        }

        return command.joined(separator: " \\\n\t")
    }
}
