import XCTest
import APIClient
import Petstore

class APIClientTests: XCTestCase {
    lazy var client: Client = {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"

        let configuration = Configuration(dateDecodingStrategy: .formatted(dateFormatter))
        let client = Client(baseURL: URL(string: "https://petstore.swagger.io/v2")!,
                            configuration: configuration)
        return client
    }()

    override func setUp() {
        super.setUp()
        client.interceptors = [Logger()]

        let ex = expectation(description: "testAddPet")

        let category = Category(_id: 1234, name: "eyeColor")
        let tags = [Tag(_id: 1234, name: "New York"), Tag(_id: 124321, name: "Jose")]
        let newPet = Pet(_id: 1000, category: category, name: "Fluffy", photoUrls: ["https://petstore.com/sample/photo1.jpg", "https://petstore.com/sample/photo2.jpg"], tags: tags, status: .available)

        client.perform(request: PetAPI.addPet(pet: newPet).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testQueryParameter1() {
        struct Interceptor: Intercepting {
            func intercept(client: Client, request: URLRequest) -> URLRequest {
                XCTAssertEqual(request.url?.query, "tags=kishikawakatsumi+test@gmail.com")
                return request
            }
        }
        
        client.interceptors = client.interceptors + [Interceptor()]

        let ex = expectation(description: "testQueryParameter1")
        client.perform(request: PetAPI.findPetsByTags(tags: ["kishikawakatsumi+test@gmail.com"]).request()) { _ in
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testQueryParameter2() {
        struct Interceptor: Intercepting {
            func intercept(client: Client, request: URLRequest) -> URLRequest {
                XCTAssertEqual(request.url?.query?.removingPercentEncoding, "tags=a b+c")
                return request
            }
        }

        client.interceptors = client.interceptors + [Interceptor()]

        let ex = expectation(description: "testQueryParameter2")
        client.perform(request: PetAPI.findPetsByTags(tags: ["a b+c"]).request()) { _ in
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testFormParameter1() {
        struct Interceptor: Intercepting {
            func intercept(client: Client, request: URLRequest) -> URLRequest {
                if let httpBody = request.httpBody {
                    XCTAssertEqual(String(data: httpBody, encoding: .utf8)?.removingPercentEncoding, "name=kishikawakatsumi+test@gmail.com")
                }
                return request
            }
        }

        client.interceptors = client.interceptors + [Interceptor()]

        let ex = expectation(description: "testFormParameter1")
        client.perform(request: PetAPI.updatePetWithForm(petId: 0, name: "kishikawakatsumi+test@gmail.com", status: nil).request()) { _ in
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testAddPet() {
        let ex = expectation(description: "testAddPet")

        let category = Category(_id: 1234, name: "eyeColor")
        let tags = [Tag(_id: 1234, name: "New York"), Tag(_id: 124321, name: "Jose")]
        let newPet = Pet(_id: 1000, category: category, name: "Fluffy", photoUrls: ["https://petstore.com/sample/photo1.jpg", "https://petstore.com/sample/photo2.jpg"], tags: tags, status: .available)

        client.perform(request: PetAPI.addPet(pet: newPet).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testUpdatePet() {
        let ex = expectation(description: "testUpdatePet")

        let category = Category(_id: 1234, name: "eyeColor")
        let tags = [Tag(_id: 1234, name: "New York"), Tag(_id: 124321, name: "Jose")]
        let newPet = Pet(_id: 1000, category: category, name: "Fluffy", photoUrls: ["https://petstore.com/sample/photo1.jpg", "https://petstore.com/sample/photo2.jpg"], tags: tags, status: .available)

        client.perform(request: PetAPI.updatePet(pet: newPet).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testGetPetById() {
        let ex = expectation(description: "testGetPetById")

        self.client.perform(request: PetAPI.getPetById(petId: 1000).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
                let pet = response.body
                XCTAssertEqual(pet._id, 1000, "invalid id")
                XCTAssertEqual(pet.name, "Fluffy", "invalid name")
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testUpdatePetWithForm() {
        let ex = expectation(description: "")

        self.client.perform(request: PetAPI.updatePetWithForm(petId: 1000, name: "Fluffy", status: Pet.Status.available.rawValue).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }
        waitForExpectations(timeout: 10)
    }

    func testDeletePet() {
        let ex = expectation(description: "testDeletePet")

        client.perform(request: PetAPI.deletePet(petId: 1000).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testGetInventory() {
        let ex = expectation(description: "")

        client.perform(request: StoreAPI.getInventory().request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testPlaceOrder() {
        let ex = expectation(description: "testPlaceOrder")

        let shipDate = Date()
        let order = Order(_id: 1000, petId: 1000, quantity: 10, shipDate: shipDate, status: .placed, complete: true)
        client.perform(request: StoreAPI.placeOrder(order: order).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)

                XCTAssert(response.body._id == 1000, "invalid id")
                XCTAssert(response.body.quantity == 10, "invalid quantity")
                XCTAssert(response.body.status == .placed, "invalid status")
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testGetOrderById() {
        var ex = expectation(description: "testPlaceOrder")

        let shipDate = Date()
        let order = Order(_id: 1000, petId: 1000, quantity: 10, shipDate: shipDate, status: .placed, complete: true)
        client.perform(request: StoreAPI.placeOrder(order: order).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)

                XCTAssert(response.body._id == 1000, "invalid id")
                XCTAssert(response.body.quantity == 10, "invalid quantity")
                XCTAssert(response.body.status == .placed, "invalid status")
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)

        ex = expectation(description: "testGetOrderById")

        client.perform(request: StoreAPI.getOrderById(orderId: 1000).request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)

                XCTAssert(response.body._id == 1000, "invalid id")
                XCTAssert(response.body.quantity == 10, "invalid quantity")
                XCTAssert(response.body.status == .placed, "invalid status")
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testLoginUser() {
        let ex = expectation(description: "testLoginUser")

        client.perform(request: UserAPI.loginUser(username: "swiftTester", password: "swift").request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }

    func testLogoutUser() {
        let ex = expectation(description: "testLogoutUser")

        client.perform(request: UserAPI.logoutUser().request()) {
            switch $0 {
            case .success(let response):
                XCTAssertEqual(response.statusCode, 200)
            case .failure(let error):
                XCTFail("request failed: \(error)")
            }
            ex.fulfill()
        }

        waitForExpectations(timeout: 10)
    }
}
