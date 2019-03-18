[![Build Status](https://app.bitrise.io/app/fb217dd8dc7e8002/status.svg?token=zgTIlwz2Qz-YPsOK6rQxUQ)](https://app.bitrise.io/app/fb217dd8dc7e8002)
[![codecov](https://codecov.io/gh/folio-sec/APIClient/branch/master/graph/badge.svg)](https://codecov.io/gh/folio-sec/APIClient)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

# APIClient

APIClient is a client library for OpenAPI. It makes OpenAPI generated code remarkably more straightforward than the default one. 

The generated code by  Open API is a strongly tied scheme definition and networking code. It makes debugging and logging difficult. This library separates networking code from OpenAPI generated code, and you can depend on only schema and model definitions.


#### BEFORE

```swift
import Foundation
import Alamofire

open class PetAPI {
    open class func getPetById(petId: Int64, completion: @escaping ((_ data: Pet?,_ error: Error?) -> Void)) {
        getPetByIdWithRequestBuilder(petId: petId).execute { (response, error) -> Void in
            completion(response?.body, error)
        }
    }

    open class func getPetByIdWithRequestBuilder(petId: Int64) -> RequestBuilder<Pet> {
        var path = "/pet/{petId}"
        let petIdPreEscape = "\(petId)"
        let petIdPostEscape = petIdPreEscape.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        path = path.replacingOccurrences(of: "{petId}", with: petIdPostEscape, options: .literal, range: nil)
        let URLString = PetstoreAPI.basePath + path
        let parameters: [String:Any]? = nil
        
        let url = URLComponents(string: URLString)

        let requestBuilder: RequestBuilder<Pet>.Type = PetstoreAPI.requestBuilderFactory.getBuilder()

        return requestBuilder.init(method: "GET", URLString: (url?.string ?? URLString), parameters: parameters, isBody: false)
    }
    ...
```

#### AFTER

```swift
import Foundation

open class PetAPI {
    open class func getPetById(petId: Int64) -> RequestProvider<Pet> {
        var path = "/pet/{petId}"
        let petIdPreEscape = "\(petId)"
        let petIdPostEscape = petIdPreEscape.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
        path = path.replacingOccurrences(of: "{petId}", with: petIdPostEscape, options: .literal, range: nil)
        
        return RequestProvider<Pet>(endpoint: path, method: "GET")
    }
    ...
```

`RequestProvider<Response>` just encodes an endpoint (path), parameters (query, form or JSON), an HTTP method and a response type.


## Usage

Add an extension to convert OpenAPI's `RequestProvider<Response>` to APIClient's `Request<Response>`.

```swift
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
```

Initialize `Client` instance.

```swift
let client = Client(baseURL: URL(string: "https://petstore.swagger.io/v2")!)
...
```

Then you can call `Client.perform` with `Request<Response>` object.

```swift
client.perform(request: PetAPI.getPetById(petId: 1000).request()) {
    switch $0 {
    case .success(let response):
        let pet = response.body
        ...
    case .failure(let error):
        ...
    }
}
```

## Installation ##

### [Carthage] ###

[Carthage]: https://github.com/Carthage/Carthage

```
github "folio-sec/APIClient"
```

Then run `carthage update`.

Follow the current instructions in [Carthage's README][carthage-installation]
for up to date installation instructions.

[carthage-installation]: https://github.com/Carthage/Carthage#adding-frameworks-to-an-application

## Advanced

### Interceptor

APIClient supports request and response interceptors.

The following example is a logger interceptor.

```swift
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
        ...
    }
}
```

```swift
client.interceptors = [Logger()]
...
```

### Authenticator

The Authenticator has an opportunity to retry when it receives a 401 response. It will be used to seamlessly refresh access tokens.

```swift
import Foundation
import APIClient

struct Authenticator: Intercepting, Authenticating {
    private let credentials: Credentials

    init(credentials: Credentials) {
        self.credentials = credentials
    }

    func intercept(client: Client, request: URLRequest) -> URLRequest {
        return sign(request: request)
    }

    func authenticate(client: Client, request: URLRequest, response: HTTPURLResponse, data: Data?, completion: @escaping (AuthenticationResult) -> Void) {
        switch response.statusCode {
        case 401:
            if let url = request.url, !url.path.hasSuffix("/login"), let refreshToken = credentials.fetch()?.refreshToken {
                client.perform(request: AuthenticationAPI.authorize(refreshToken: refreshToken).request()) {
                    switch $0 {
                    case .success(let response):
                        let body = response.body
                        self.credentials.update(token: Token(accessToken: body.accessToken, refreshToken: body.refreshToken, expiry: Date().addingTimeInterval(TimeInterval(body.expiresIn))))
                        completion(.success(self.sign(request: request)))
                        return
                    case .failure(let error):
                        switch error {
                        case .networkError, .decodingError:
                            completion(.failure(error))
                            return
                        case .responseError(let code, _, _):
                            switch code {
                            case 400...499:
                                self.credentials.update(token: nil)
                                completion(.failure(error))
                                return
                            case 500...499:
                                completion(.failure(error))
                                return
                            default:
                                break
                            }
                        }
                        completion(.failure(error))
                        return
                    }
                }
            } else {
                completion(.cancel)
                return
            }
        default:
            completion(.cancel)
            return
        }
    }

    private func sign(request: URLRequest) -> URLRequest {
        var request = request
        if let url = request.url, !url.path.hasSuffix("/login") {
            if let accessToken = credentials.fetch()?.accessToken {
                request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            }
        }
        return request
    }
}
```

```swift
let authenticator = Authenticator(credentials: credentials)
client.authenticator = authenticator
client.interceptors = [authenticator] + client.interceptors // for signing all requests
...
```
