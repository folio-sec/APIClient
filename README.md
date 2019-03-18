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

`RequestProvider<Response>` just encodes an endpoint (path), parameters (query, form or JSON), a HTTP method and a response type.


### Usage

Add extension to convert OpenAPI's `RequestProvider<Response>` to APIClient's `Request<Response>`.

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
