import Foundation

public struct Response<ResponseBody> {
    public let statusCode: Int
    public let headers: [AnyHashable: Any]
    public let body: ResponseBody

    public init(statusCode: Int, headers: [AnyHashable: Any], body: ResponseBody) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

public enum Failure: Error {
    case networkError(Error)
    case decodingError(Error, Int, [AnyHashable: Any], Data)
    case responseError(Int, [AnyHashable: Any], Data)
}
