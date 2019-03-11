import Foundation

public struct Configuration {
    public let dateDecodingStrategy: JSONDecoder.DateDecodingStrategy
    public let dataDecodingStrategy: JSONDecoder.DataDecodingStrategy

    public let timeoutIntervalForRequest: TimeInterval
    public let timeoutIntervalForResource: TimeInterval

    public let queue: DispatchQueue

    public init(dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .iso8601, dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .base64, timeoutIntervalForRequest: TimeInterval = 60, timeoutIntervalForResource: TimeInterval = 604800, queue: DispatchQueue = DispatchQueue.main) {
        self.dateDecodingStrategy = .iso8601
        self.dataDecodingStrategy = .base64
        self.timeoutIntervalForRequest = timeoutIntervalForRequest
        self.timeoutIntervalForResource = timeoutIntervalForResource
        self.queue = queue
    }
}
