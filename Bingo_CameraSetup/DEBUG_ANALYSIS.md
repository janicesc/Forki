# Debug Analysis: Calorie Camera Flow

## Summary of Logs

### ✅ What's Working

1. **API Call (Supabase Edge Function)**: ✅ Perfect
   - Returns: "Orange", 62 calories, macros (protein=0.9g, carbs=15.4g, fat=0.2g)
   - Response time: 5.4 seconds
   - Status: 200 OK

2. **Label Preservation**: ✅ Working
   - API label "Orange" is correctly preserved through the entire flow
   - No generic "Detected Food" fallback

3. **Fallback Logic**: ✅ Working
   - When Geometry V2 fails, correctly falls back to API values
   - Uses upper bound: 62 + 2×12 = 86 calories

4. **Bridge Conversion**: ✅ Working
   - Converts CalorieResult to AICameraNutritionResult correctly
   - Extracts macros from evidence

5. **HomeScreen Integration**: ✅ Working
   - Receives result and shows FoodLoggerView

### ❌ Issues Found

#### Issue 1: Geometry Estimator V2 - NO DEPTH DATA ⚠️

**Problem**: All 3 frames return "NO DEPTH DATA: Cannot calculate volume-based calories"

**Root Cause**: 
- iPhone 11 uses Dual Camera Depth (not LiDAR)
- Depth data requires:
  - Good lighting conditions
  - Proper subject distance (0.5-3 meters)
  - Subject in focus
  - Both cameras can see the subject

**Why It's Failing**:
- The depth data might not be available in the photo capture
- `photo.depthData` is returning `nil` in `DepthExtractor.depthData(from:)`
- This could be due to:
  1. Lighting conditions (too dark/bright)
  2. Subject too close/far from camera
  3. Depth data not enabled in photo settings (but code shows it is enabled)
  4. Photo delegate not waiting for depth data

**Impact**: 
- Geometry V2 cannot calculate volume
- Falls back to API calories (which is correct behavior)
- But we lose the precision of volume-based estimation

**Fix Needed**:
- Add logging to see if `photo.depthData` is nil
- Check if depth data delivery is actually enabled
- Verify iPhone 11 dual camera depth is working
- Consider adding a fallback that uses 2D area estimation when depth is unavailable

#### Issue 2: USDA Lookup - Wrong Match ⚠️

**Problem**: "Orange" is matching "10 oz Orange Juice PET" instead of "Orange"

**Root Cause**: 
- The matching logic is too loose
- "orange" contains "orange juice", so it matches

**Fix Applied**: 
- Updated matching logic to prefer exact matches
- Added check to avoid juice/drink when searching for fruit names
- Now prioritizes: exact match → starts with query → first word match → partial match

#### Issue 3: Macros Calculation - Slight Discrepancy ⚠️

**API Returns**:
- protein=0.9g, carbs=15.4g, fat=0.2g (for 62 calories)

**Bridge Calculates**:
- protein=3.875g, carbs=6.975g, fat=2.066g (for 86 calories)

**Why**: 
- Bridge is calculating macros from the upper bound calories (86) using standard ratios
- But API already provided macros for 62 calories
- Should use API macros scaled to 86 calories, not recalculate from scratch

**Fix Needed**:
- Scale API macros proportionally: `(86/62) * API_macros`
- Instead of recalculating from calories using standard ratios

## Flow Summary

```
1. User captures photo
   ↓
2. Capture 3 frames (for temporal fusion)
   ↓
3. API Call (Supabase Edge Function)
   ✅ Returns: "Orange", 62 cal, macros
   ↓
4. Geometry Estimator V2
   ❌ NO DEPTH DATA (all 3 frames fail)
   ↓
5. Fallback to API
   ✅ Uses: 86 calories (upper bound), calculates macros
   ↓
6. Bridge Conversion
   ✅ Converts to AICameraNutritionResult
   ✅ Label: "Orange", Calories: 86
   ↓
7. HomeScreen
   ✅ Receives result, shows FoodLoggerView
   ↓
8. USDA Lookup
   ⚠️ Matches "Orange Juice" (should match "Orange")
   ✅ Fixed with improved matching logic
```

## Next Steps

1. ✅ **Fixed**: USDA lookup matching logic
2. 🔧 **To Fix**: Add depth data logging to diagnose why depth isn't available
3. 🔧 **To Fix**: Scale API macros instead of recalculating
4. 📊 **To Monitor**: Check if depth data becomes available with better lighting/distance

