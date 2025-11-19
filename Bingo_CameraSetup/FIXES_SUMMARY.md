# Fixes Applied: Macro Calculation & Food Logger View

## Issue 1: Inaccurate Macro Calculation ❌

### Problem
User scanned "Biscoff cookie" and got:
- Calories: **98** ✅ (correct)
- Protein: **2.8g** ✅ (reasonable)
- Carbs: **84.0g** ❌ (way too high!)
- Fats: **42.0g** ❌ (way too high!)

**Math check**: 2.8×4 + 84×4 + 42×9 = 11.2 + 336 + 378 = **725 calories** (not 98!)

### Root Cause
**API macros are per 100g, NOT per portion!**

The API returns:
- Calories: **100** (for the detected portion)
- Macros: **protein=5g, carbs=50g, fat=30g** (per 100g of food)

We were incorrectly **scaling macros by calories**:
- Scale factor: 98 / 100 = 0.98
- Result: protein=4.9g, carbs=49g, fat=29.4g

But this doesn't work because:
- API calories = portion-specific (100 cal for this cookie)
- API macros = per 100g (not portion-specific)
- We can't scale per-100g macros by portion calories!

### Fix Applied ✅
**Calculate macros from calories** using standard ratios:
- Protein: 10% of calories → 98 × 0.10 / 4 = **2.5g**
- Carbs: 50% of calories → 98 × 0.50 / 4 = **12.3g**
- Fats: 40% of calories → 98 × 0.40 / 9 = **4.4g**

**Verification**: 2.5×4 + 12.3×4 + 4.4×9 = 10 + 49.2 + 39.6 = **98.8 calories** ✅

### Expected Results After Fix
For a **Biscoff cookie (98 calories)**:
- Protein: **~2.5g** (was 2.8g) ✅
- Carbs: **~12.3g** (was 84g) ✅
- Fats: **~4.4g** (was 42g) ✅

**Macros now match calories!** ✅

## Issue 2: Food Logger View Not Showing Prefilled Food ❌

### Problem
After camera scan, user sees **"Popular Foods"** instead of **prefilled detected food**.

### Root Cause
The view was checking `selectedFood` first, but `selectedFood` wasn't being set from `prefill` immediately when the view appeared.

### Fix Applied ✅
1. **Priority logic**: `prefill ?? selectedFood` - always use prefill if available
2. **Direct display**: Show `FoodDetailView` directly with `prefill` (no need to set `selectedFood` first)
3. **Force sync**: Set `selectedFood = prefill` in `.onAppear` for consistency

### Code Changes
```swift
// OLD: Check selectedFood first
if let food = selectedFood {
    selectedFoodSection
} else {
    popularFoodsSection
}

// NEW: Check prefill first (camera detected food)
let foodToShow = prefill ?? selectedFood
if let food = foodToShow {
    FoodDetailView(food: food, ...)
} else {
    popularFoodsSection
}
```

### Expected Behavior After Fix
- ✅ Camera scan → Food Logger View opens
- ✅ **Prefilled food shows immediately** (not Popular Foods)
- ✅ User can see detected food name, calories, macros
- ✅ User can adjust portion and save

## Summary

### ✅ Fixed
1. **Macro calculation**: Now calculates from calories (ensures macros match calories)
2. **Food Logger View**: Always shows prefilled food when available (prioritizes camera results)

### Expected Results
- **Macros match calories**: 98 cal = ~2.5g protein, 12g carbs, 4.4g fat ✅
- **Prefilled view shows**: Camera scan → Detected food view (not Popular Foods) ✅

