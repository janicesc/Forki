# Fix: Extremely High Calorie/Macro Values

## Problem

User scanned a **Biscoff Cookie** and got values hitting all safety caps:
- Calories: **2,000** (max cap)
- Protein: **200.0g** (max cap)
- Carbs: **300.0g** (max cap)
- Fats: **155.6g** (very high)

**Expected for a cookie**: ~30-50 calories, <1g protein, 4-6g carbs, 1-2g fats

## Root Cause

The **Geometry Estimator V2** is calculating volume incorrectly, producing values **10-100x too high**. This happens when:

1. **Depth data is available** (unlike iPhone 11 which had no depth)
2. **Volume calculation error**: 
   - Area × Height might be calculated incorrectly
   - Unit conversion might be wrong
   - Depth map might have wrong scale
3. **Result**: Volume = 1000+ mL → Calories = 1000+ → Macros scale to caps

## Fix Applied

Added **validation for unreasonably high values** in `CalorieCameraView.swift`:

### Before Geometry Values Are Used:
1. **Check if calories > 1000** or **volume > 1000 mL**
2. If yes: **Reject geometry estimate** and **fallback to API values**
3. **Cap API upper bound** at 1000 calories (instead of 2000)
4. **Log warning** with actual values for debugging

### Code Changes:

```swift
// CRITICAL: Check for unreasonably high values (likely calculation error)
let maxReasonableCalories = 1000.0  // Cap at 1000 calories
let maxReasonableVolume = 1000.0    // Cap at 1000 mL

if geometryCalories > maxReasonableCalories || geometryVolumeML > maxReasonableVolume {
    // Reject geometry, use API fallback
    // Cap API upper bound at 1000 calories
}
```

## Why This Works

1. **Geometry Estimator V2** is still experimental and can produce errors
2. **API values** are more reliable for portion-specific estimates
3. **1000 calorie cap** is more reasonable than 2000 for single food items
4. **Fallback logic** ensures we always have usable data

## Next Steps

1. **Test again** with the fix - should now use API values when geometry is too high
2. **Check logs** to see what volume/calories geometry is calculating
3. **Investigate geometry calculation** if errors persist:
   - Check depth map units
   - Check area calculation
   - Check height calculation
   - Check unit conversions

## Expected Behavior After Fix

- **If geometry is reasonable** (< 1000 cal, < 1000 mL): Use geometry values ✅
- **If geometry is too high** (> 1000 cal or > 1000 mL): Use API values ✅
- **API upper bound capped** at 1000 calories (not 2000) ✅
- **Macros scaled** from API values proportionally ✅

## Debugging

If high values still occur, check logs for:
- `⚠️⚠️⚠️ [PRECISE] WARNING: Geometry V2 returned suspiciously HIGH values!`
- Actual volume and calories calculated
- Whether fallback to API was triggered

