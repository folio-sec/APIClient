import Foundation
import APIClient
import Petstore

extension RequestProvider {
    func request() -> Request<Response> {
        if let parameters = parameters {
            switch parameters {
            case .query(let raw):
                return Request(endpoint: endpoint, method: method, parameters: Request.Parameters(raw))
            case .form(let raw):
                return Request(endpoint: endpoint, method: method, parameters: Request.Parameters(raw))
            case .json(let raw):
                return Request(endpoint: endpoint, method: method, parameters: Request.Parameters(raw))
            }
        }
        return Request(endpoint: endpoint, method: method)
    }
}
