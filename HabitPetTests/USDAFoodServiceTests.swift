//
//  USDAFoodServiceTests.swift
//  Forki
//
//  Created by Janice C on 9/17/25.
//

import XCTest
import Combine
@testable import Forki

/// Tests for USDA FoodData Central integration
class USDAFoodServiceTests: XCTestCase {
    
    var service: USDAFoodService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        service = USDAFoodService.shared
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        service.clearAllCaches()
        cancellables = nil
        service = nil
        super.tearDown()
    }
    
    // MARK: - Mock Data Tests
    
    func testMockFoods() {
        let mockFoods = service.getMockFoods()
        
        XCTAssertFalse(mockFoods.isEmpty, "Mock foods should not be empty")
        XCTAssertEqual(mockFoods.count, 10, "Should have 10 mock foods")
        
        // Test first food item
        let apple = mockFoods.first { $0.name.contains("Apple") }
        XCTAssertNotNil(apple, "Should have an apple in mock foods")
        XCTAssertEqual(apple?.calories, 52, "Apple should have 52 calories")
    }
    
    // MARK: - API Configuration Tests
    
    func testAPIKeyConfiguration() {
        // Test with demo key
        XCTAssertFalse(USDAConfig.isApiKeyConfigured, "Demo key should not be considered configured")
        
        // Test API endpoints
        XCTAssertEqual(USDAConfig.baseURL, "https://api.nal.usda.gov/fdc/v1")
        XCTAssertEqual(USDAConfig.searchFoodsURL, "https://api.nal.usda.gov/fdc/v1/foods/search")
    }
    
    func testNutrientIDs() {
        XCTAssertEqual(USDAConfig.NutrientIDs.energy, 1008)
        XCTAssertEqual(USDAConfig.NutrientIDs.protein, 1003)
        XCTAssertEqual(USDAConfig.NutrientIDs.carbohydrates, 1005)
        XCTAssertEqual(USDAConfig.NutrientIDs.totalLipid, 1004)
    }
    
    func testNutrientNames() {
        XCTAssertEqual(USDAConfig.nutrientName(for: 1008), "Energy")
        XCTAssertEqual(USDAConfig.nutrientName(for: 1003), "Protein")
        XCTAssertEqual(USDAConfig.nutrientUnit(for: 1008), "kcal")
        XCTAssertEqual(USDAConfig.nutrientUnit(for: 1003), "g")
    }
    
    // MARK: - Search Parameter Tests
    
    func testSearchQueryParameters() {
        let params = USDAConfig.buildSearchQueryParameters(
            query: "apple",
            pageSize: 25,
            pageNumber: 1,
            dataType: "Foundation"
        )
        
        XCTAssertEqual(params["query"], "apple")
        XCTAssertEqual(params["pageSize"], "25")
        XCTAssertEqual(params["pageNumber"], "1")
        XCTAssertEqual(params["dataType"], "Foundation")
        XCTAssertEqual(params["sortBy"], "lowercaseDescription.keyword")
        XCTAssertEqual(params["sortOrder"], "asc")
    }
    
    // MARK: - Cache Tests
    
    func testCacheClearing() {
        // Test that cache clearing methods exist and don't crash
        XCTAssertNoThrow(service.clearSearchCache(), "Clear search cache should not throw")
        XCTAssertNoThrow(service.clearFoodDetailsCache(), "Clear food details cache should not throw")
        XCTAssertNoThrow(service.clearAllCaches(), "Clear all caches should not throw")
    }
    
    // MARK: - FoodItem Conversion Tests
    
    func testUSDAFoodToFoodItemConversion() {
        // Create mock USDA food data
        let mockNutrient = FoodNutrient(
            id: 1,
            amount: 52.0,
            dataPoints: nil,
            min: nil,
            max: nil,
            median: nil,
            type: nil,
            nutrient: Nutrient(
                id: 1008,
                number: "208",
                name: "Energy",
                rank: 100,
                unitName: "kcal",
                unitSymbol: "kcal",
                unitConversionFactor: nil,
                nutrientClass: nil,
                nutrientRank: nil,
                lastUpdated: nil
            ),
            foodNutrientDerivation: nil,
            foodNutrientSource: nil,
            foodNutrientSourceId: nil,
            plStudyId: nil,
            retentionFactor: nil,
            subSampleId: nil
        )
        
        let mockUSDAFood = USDAFood(
            fdcId: 12345,
            description: "Apple, raw, with skin",
            dataType: "Foundation",
            gtinUpc: nil,
            publishedDate: nil,
            brandOwner: nil,
            brandName: nil,
            ingredients: nil,
            marketCountry: nil,
            foodCategory: FoodCategory(id: 1, code: "0900", description: "Fruits and Fruit Juices"),
            modifiedDate: nil,
            dataSource: nil,
            packageWeight: nil,
            servingSizeUnit: nil,
            servingSize: nil,
            householdServingFullText: nil,
            tradeChannels: nil,
            allHighlightFields: nil,
            score: nil,
            microbes: nil,
            foodNutrients: [mockNutrient],
            finalFoodInputFoods: nil,
            foodMeasures: nil,
            foodAttributes: nil,
            foodAttributeTypes: nil,
            foodVersionIds: nil,
            foodComponents: nil,
            footnote: nil,
            foodClass: nil,
            foodCode: nil,
            foodDescription: nil,
            foodId: nil,
            foodName: nil,
            foodStatus: nil,
            foodType: nil,
            foodUrl: nil,
            publicationDate: nil,
            scientificName: nil,
            ndbNumber: nil,
            additionalDescriptions: nil,
            foodUpdateLog: nil,
            inputFoods: nil,
            labels: nil,
            langualFactors: nil,
            nutrientConversionFactors: nil,
            nutrientDataSources: nil,
            sampleFoods: nil,
            subSampleFoods: nil,
            tableAliasNames: nil,
            wweiaFoodCategory: nil
        )
        
        let foodItem = mockUSDAFood.toFoodItem()
        
        XCTAssertEqual(foodItem.id, 12345)
        XCTAssertEqual(foodItem.name, "Apple, raw, with skin")
        XCTAssertEqual(foodItem.calories, 52)
        XCTAssertEqual(foodItem.category, "Fruits and Fruit Juices")
        XCTAssertNotNil(foodItem.usdaFood)
    }
    
    // MARK: - Integration Tests (Requires Network)
    
    func testSearchWithFallback() {
        let expectation = XCTestExpectation(description: "Search with fallback")
        
        service.searchFoodsWithFallback(query: "apple")
            .sink(
                receiveCompletion: { completion in
                    switch completion {
                    case .finished:
                        expectation.fulfill()
                    case .failure(let error):
                        // Even if API fails, we should get mock data
                        print("API Error (expected in tests): \(error)")
                        expectation.fulfill()
                    }
                },
                receiveValue: { foods in
                    XCTAssertFalse(foods.isEmpty, "Should return some foods")
                    // Verify at least one apple is in the results
                    let hasApple = foods.contains { $0.name.lowercased().contains("apple") }
                    XCTAssertTrue(hasApple, "Should contain apple in results")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 10.0)
    }
}

// MARK: - Test Helper Methods

extension USDAFoodServiceTests {
    
    /// Test that service can be initialized
    func testServiceInitialization() {
        XCTAssertNotNil(service, "Service should be initialized")
        XCTAssertEqual(service, USDAFoodService.shared, "Should be singleton")
    }
    
    /// Test error handling
    func testErrorHandling() {
        let expectation = XCTestExpectation(description: "Error handling")
        
        // Test with empty query
        service.searchFoods(query: "")
            .sink(
                receiveCompletion: { completion in
                    if case .failure = completion {
                        expectation.fulfill()
                    }
                },
                receiveValue: { _ in
                    XCTFail("Should not receive value for empty query")
                }
            )
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 5.0)
    }
}
