# USDA FoodData Central Integration

This document explains how to set up and use the USDA FoodData Central integration in your iOS app.

## Overview

The app now integrates with the USDA FoodData Central API to provide comprehensive food search functionality. This allows users to search for any food item from the extensive USDA database and get accurate nutritional information.

## Setup Instructions

### 1. Get a USDA API Key

1. Visit [https://api.data.gov/signup/](https://api.data.gov/signup/)
2. Sign up for a free account
3. Once registered, you'll receive an API key

### 2. Configure the API Key

1. Open `Onboarding/USDAConfig.swift`
2. Replace `"DEMO_KEY"` with your actual API key:

```swift
static let apiKey = "YOUR_ACTUAL_API_KEY_HERE"
```

### 3. Test the Integration

The app includes fallback mock data, so it will work even without an API key, but with limited functionality.

## Features

### Food Search
- **Real-time search**: As users type, the app searches the USDA database
- **Debounced requests**: Prevents excessive API calls
- **Fallback support**: Uses mock data if API is unavailable
- **Error handling**: Graceful error messages for network issues

### Data Sources
The app prioritizes data from these sources (in order):
1. **Foundation Foods**: Lab-quality nutrient data (highest accuracy)
2. **SR Legacy**: USDA's legacy nutrient database
3. **Branded Foods**: Branded food products

### Enhanced Nutrition Display
- **Macronutrients**: Calories, protein, carbohydrates, fats
- **Additional nutrients**: Fiber, calcium, sodium, iron, vitamins
- **USDA verification**: Shows USDA data source indicator
- **Data type labels**: Indicates whether data is from Foundation, SR Legacy, or Branded sources

## Technical Implementation

### Key Files

- `USDAFoodModels.swift`: Data models for USDA API responses
- `USDAFoodService.swift`: API service for making requests
- `USDAConfig.swift`: Configuration and constants
- `FoodLoggerView.swift`: Updated UI with USDA integration

### Data Models

The `USDAFood` struct maps to the USDA API response and includes:
- Basic food information (name, category, description)
- Comprehensive nutrient data
- Metadata (data source, publication date, etc.)

### API Service

The `USDAFoodService` class provides:
- Search functionality with caching
- Detailed food information retrieval
- Error handling and fallbacks
- Mock data for development

### Caching

The service implements intelligent caching:
- Search results are cached to reduce API calls
- Food details are cached for faster subsequent access
- Cache can be cleared manually if needed

## Usage Examples

### Basic Search
```swift
let service = USDAFoodService.shared
service.searchFoods(query: "apple")
    .sink(
        receiveCompletion: { completion in
            // Handle completion
        },
        receiveValue: { foods in
            // Handle search results
        }
    )
    .store(in: &cancellables)
```

### Get Food Details
```swift
service.getFoodDetails(fdcId: 12345)
    .sink(
        receiveCompletion: { completion in
            // Handle completion
        },
        receiveValue: { food in
            // Handle detailed food data
        }
    )
    .store(in: &cancellables)
```

## API Limits

- **Rate limit**: 1,000 requests per hour per IP address
- **Page size**: Maximum 200 results per request
- **Free tier**: No cost for basic usage

## Error Handling

The integration includes comprehensive error handling:
- Network connectivity issues
- API rate limiting
- Invalid responses
- Missing API keys

## Development Notes

### Mock Data
When the API is unavailable or for development purposes, the app uses mock data from `USDAFoodService.getMockFoods()`.

### Testing
- Use the demo API key for testing (limited functionality)
- Implement unit tests using mock responses
- Test error scenarios with network simulation

### Performance
- Search requests are debounced (500ms delay)
- Results are cached to reduce API calls
- UI updates are performed on the main thread

## Future Enhancements

Potential improvements to consider:
1. **Offline support**: Download and store USDA data locally
2. **Advanced filtering**: Filter by food categories, allergens, etc.
3. **Nutrition analysis**: Calculate daily nutrition goals
4. **Barcode scanning**: Integrate with barcode lookup
5. **Food suggestions**: AI-powered food recommendations

## Troubleshooting

### Common Issues

1. **No search results**: Check API key configuration
2. **Network errors**: Verify internet connectivity
3. **Rate limiting**: Reduce search frequency or implement better caching
4. **Decoding errors**: Check for API response format changes

### Debug Mode

Enable debug logging by setting:
```swift
// In USDAConfig.swift
static let debugMode = true
```

## Support

For issues with the USDA API:
- [USDA FoodData Central API Documentation](https://fdc.nal.usda.gov/api-guide)
- [Data.gov Support](https://www.data.gov/contact/)

For app-specific issues, check the console logs and error messages displayed in the UI.

