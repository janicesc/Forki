# 📸 HabitPet Camera Integration Plan

## Executive Summary

This document outlines the comprehensive plan to integrate advanced AI camera features into the HabitPet web application by leveraging the existing CalorieCameraKit (Swift iOS library) backend through Supabase Edge Functions.

---

## 🔍 Current State Analysis

### **What You Have:**

#### 1. **janicesc/HabitPet (GitHub Repository)**
- **Type:** Native iOS app (Swift 55.1%, TypeScript 44.9%)
- **Backend:** Supabase with Edge Functions
- **Food Data:** USDA FoodData Central integration
- **Features:**
  - Virtual pet that responds to eating habits
  - USDA food database search
  - Nutritional tracking
  - Supabase `analyze_food` function
  - Real-time food search with caching
  - Mock data fallback

#### 2. **Your Current Project** (`/Users/wutthichaiupatising/habit_pet`)
- **Type:** Next.js 15.5.4 web app + Swift CalorieCameraKit
- **Components:**
  - **Web Camera:** 4 different implementations (CameraCapture.tsx, FinalCameraCapture.tsx, etc.)
  - **CalorieCameraKit:** Advanced Swift package with:
    - 3-path routing (Label/Menu/Geometry)
    - Depth-based volume estimation (LiDAR)
    - AI classification via OpenAI Vision
    - Statistical fusion engine
    - Delta method uncertainty propagation
  - **Supabase Function:** `analyze_food` with OpenAI Vision
  - **Backend:** Same Supabase setup

---

## 🚨 Critical Issues Identified

### **CalorieCameraKit (Swift) - BROKEN**
From our earlier analysis, the iOS CalorieCameraKit has 5 critical bugs:

1. ❌ **Volume estimation returns 0** - Mask pixel reading not implemented
2. ❌ **Camera intrinsics always nil** - Can't unproject depth to 3D
3. ❌ **Segmentation is mock** - Full-frame mask, no instance detection
4. ❌ **Classification hardcoded** - Always returns "rice"
5. ⚠️ **Security issue** - Logging user images to console

**Test Results:** 3 of 28 tests failing (all volume-related)

### **Web Camera (Next.js) - WORKING BUT LIMITED**
- ✅ Basic camera capture works
- ✅ Can take photos
- ✅ Sends to Supabase `analyze_food` function
- ❌ No depth sensing
- ❌ No volume estimation
- ❌ No multi-food detection
- ❌ No offline mode

---

## 🎯 Integration Strategy

### **Option A: Web-Only Approach** (RECOMMENDED)
**Leverage what works, fix what's broken**

```
User Web App (Next.js)
    ↓
Web Camera (already working)
    ↓
Capture photo + optional metadata
    ↓
Supabase Edge Function: analyze_food
    ↓
OpenAI Vision API (gpt-4o-mini)
    ↓
Return: {food, calories, confidence, priors}
    ↓
Display in HabitPet UI
```

**Pros:**
- ✅ Works on any device (no LiDAR required)
- ✅ Supabase function already exists
- ✅ OpenAI Vision already integrated
- ✅ No Swift bugs to fix
- ✅ Cross-platform (iOS, Android, Desktop)

**Cons:**
- ❌ No depth-based volume estimation
- ❌ Less accurate than depth sensing

---

### **Option B: Hybrid Approach** (ADVANCED)
**Fix CalorieCameraKit + Keep Web Fallback**

```
Platform Detection
    ↓
├── iOS (Safari) with LiDAR
│   ↓
│   CalorieCameraKit (Fixed Swift package)
│   ↓
│   3-path routing + depth volume
│   ↓
│   High accuracy estimates
│
└── Web (Chrome/Safari/Others)
    ↓
    FinalCameraCapture (existing)
    ↓
    OpenAI Vision via Supabase
    ↓
    Standard estimates
```

**Pros:**
- ✅ Best accuracy on capable devices
- ✅ Graceful degradation
- ✅ Future-proof for when web gets depth APIs

**Cons:**
- ❌ Need to fix 5 CalorieCameraKit bugs
- ❌ More complex deployment
- ❌ Maintenance burden

---

## 📋 Recommended Plan: Web-Only with Enhanced Features

### **Phase 1: Fix Current Web Camera** (2-3 hours)

#### 1.1 Consolidate Camera Components
**Current:** 4 different camera implementations
**Target:** 1 unified, production-ready component

**Action:**
```bash
# Keep: FinalCameraCapture.tsx (most complete)
# Remove: CameraCapture.tsx, SimpleCameraCapture.tsx, WorkingCameraCapture.tsx
# Rename: FinalCameraCapture.tsx → ProductionCameraCapture.tsx
```

**Improvements needed:**
- ✅ Add loading states
- ✅ Better error handling
- ✅ Camera permission UI
- ✅ Photo quality validation
- ✅ Retry logic for API failures

#### 1.2 Enhance Supabase analyze_food Function
**Current location:** `/Users/wutthichaiupatising/habit_pet/supabase/functions/analyze_food/index.ts`

**Status:** Already excellent! Includes:
- ✅ Image type detection (packaged/restaurant/prepared)
- ✅ 3-path routing (label OCR / menu lookup / geometry VLM)
- ✅ OpenAI Vision integration
- ✅ Priors for density and kcal/g
- ✅ Uncertainty estimates

**Needed improvements:**
```typescript
// Add multi-food detection
// Current: Single food per image
// Target: Detect multiple foods, return array

// Add portion size hints from image context
// Current: No portion estimation
// Target: Use plate size, reference objects for size hints

// Add confidence thresholds
// Current: Returns any result
// Target: Flag low-confidence results for user confirmation
```

#### 1.3 Integrate USDA Database (from janicesc/HabitPet)
**Source:** janicesc repo has USDA integration

**Action:**
- Port USDA FoodData Central integration
- Add real-time food search
- Implement caching strategy
- Fallback to OpenAI if USDA fails

**Benefits:**
- More accurate nutritional data (lab-verified)
- 1,000 free requests/hour
- Searchable database for manual entry

---

### **Phase 2: Merge with janicesc/HabitPet Features** (4-6 hours)

#### 2.1 Adopt Their Best Practices

**From janicesc/HabitPet:**
1. **USDA Integration**
   - `USDAFoodService.swift` logic → TypeScript equivalent
   - Search with debouncing
   - Result caching
   - Foundation Foods priority

2. **Smart Caching**
   - Cache search results locally
   - Cache food details
   - Reduce API calls

3. **User Experience**
   - Real-time search as user types
   - Display data source labels
   - Error handling for network issues
   - Rate limit awareness

#### 2.2 Create Unified Food Service

**New file:** `src/lib/services/FoodService.ts`

```typescript
export class FoodService {
  // Try multiple sources in priority order
  async analyzeFoodImage(imageBase64: string): Promise<FoodAnalysis> {
    try {
      // 1. Try Supabase analyze_food (OpenAI Vision)
      const visionResult = await this.analyzeWithVision(imageBase64);

      // 2. Cross-reference with USDA for accurate nutrition
      const usdaData = await this.searchUSDA(visionResult.foodType);

      // 3. Merge results with confidence scores
      return this.mergeResults(visionResult, usdaData);
    } catch (error) {
      // 4. Fallback to manual entry with search
      return this.promptManualEntry();
    }
  }

  // Search USDA database
  async searchUSDA(query: string): Promise<USDAFood[]> {
    // Port from janicesc's Swift implementation
  }

  // Cache management
  private cache = new Map<string, CachedResult>();
}
```

#### 2.3 Update UI Flow

**Current:** `add-food/page.tsx`
**Improvements:**

```tsx
<AddFoodFlow>
  ├─ Method Selection
  │  ├─ Camera (with AI detection)
  │  ├─ USDA Search (new!)
  │  └─ Manual Entry
  │
  ├─ Camera Capture
  │  ├─ Take Photo
  │  ├─ AI Analysis (Supabase function)
  │  ├─ Show detected food + confidence
  │  └─ Option to correct if wrong
  │
  ├─ USDA Search (new!)
  │  ├─ Real-time search as user types
  │  ├─ Show Foundation/SR Legacy/Branded tags
  │  ├─ Display macros + micros
  │  └─ Cache results
  │
  └─ Confirmation
     ├─ Show food details
     ├─ Portion adjustment
     └─ Submit to log
</AddFoodFlow>
```

---

### **Phase 3: Advanced Features** (6-8 hours)

#### 3.1 Multi-Food Detection

**Update Supabase function:**
```typescript
// analyze_food/index.ts
// Change from single food to multiple foods

interface AnalyzerResponse {
  items: AnalyzerItem[];  // Array instead of single item
  meta: { ... }
}

// Use OpenAI to detect all foods in image
const prompt = "Identify ALL foods visible in this image. For each food, provide: name, estimated portion size, calories, confidence."
```

**Update UI:**
```tsx
// Show multiple detected foods
<FoodList>
  {detectedFoods.map(food => (
    <FoodItem
      name={food.label}
      calories={food.calories}
      confidence={food.confidence}
      onRemove={() => removeFood(food.id)}
      onEdit={() => editFood(food.id)}
    />
  ))}
</FoodList>
```

#### 3.2 Barcode Scanning (Web)

**New component:** `BarcodeScannerCapture.tsx`

```typescript
import { BarcodeDetector } from '@barcode-detector/wasm';

// Use Web Barcode API or library
const detectBarcode = async (imageData: ImageData) => {
  const detector = new BarcodeDetector({ formats: ['ean_13', 'upc_a'] });
  const barcodes = await detector.detect(imageData);

  if (barcodes.length > 0) {
    // Look up nutrition via Open Food Facts API
    const nutritionData = await fetchOpenFoodFacts(barcodes[0].rawValue);
    return nutritionData;
  }
};
```

**Benefits:**
- Instant nutrition for packaged foods
- Free Open Food Facts API
- No AI needed for labeled products

#### 3.3 Meal Planning Integration

**New feature:** Suggest meals based on history

```typescript
// Analyze user's eating patterns
const userPreferences = analyzeHistory(foodLogs);

// Suggest balanced meals
const suggestions = await generateMealPlan({
  dailyCalorieGoal: user.preferences.daily_calorie_goal,
  preferences: userPreferences,
  restrictions: user.dietary_restrictions
});
```

---

### **Phase 4: iOS Native Enhancement** (Optional - 8-12 hours)

**Only if you want the absolute best accuracy**

Fix the 5 CalorieCameraKit bugs:
1. ✅ Implement mask pixel reading
2. ✅ Extract camera intrinsics
3. ✅ Add Vision framework segmentation
4. ✅ Remove debug logging
5. ✅ Create CalorieCameraCoordinator

**Deploy as:**
- Progressive Web App with native capabilities
- Or: Separate iOS app download

---

## 🔧 Implementation Priority

### **🚀 Quick Wins (Do First) - 1 day**

1. **Consolidate camera components**
   - Keep `FinalCameraCapture.tsx`
   - Remove duplicates
   - Add loading/error states

2. **Enhance Supabase function**
   - Add confidence thresholds
   - Improve error messages
   - Add retry logic

3. **Add USDA search**
   - Port search logic from janicesc
   - Add to manual entry flow
   - Implement caching

**Result:** Working camera + manual search backup

---

### **📈 Medium-Term (Week 2) - 3-4 days**

4. **Multi-food detection**
   - Update OpenAI prompt
   - Update UI for multiple items
   - Add item removal/editing

5. **Barcode scanning**
   - Add barcode detection
   - Integrate Open Food Facts
   - Add to flow as option

6. **Improve UX**
   - Better visual feedback
   - Confidence indicators
   - Portion size hints

**Result:** Production-ready food tracking

---

### **🎯 Advanced (Month 2) - 1-2 weeks**

7. **iOS native camera** (optional)
   - Fix CalorieCameraKit bugs
   - Deploy as iOS app
   - Add depth-based volume

8. **Meal planning**
   - Historical analysis
   - Meal suggestions
   - Recipe integration

9. **Offline mode**
   - PWA with service workers
   - Local food database
   - Sync when online

**Result:** Best-in-class food tracking app

---

## 📊 Comparison Matrix

| Feature | Current Web | janicesc/HabitPet | Recommended |
|---------|-------------|-------------------|-------------|
| **Camera Capture** | ✅ Working | iOS only | ✅ Keep web |
| **AI Detection** | ✅ OpenAI | Unknown | ✅ Enhanced |
| **USDA Search** | ❌ None | ✅ Full integration | ✅ Add this |
| **Multi-food** | ❌ Single | Unknown | ✅ Add this |
| **Barcode** | ❌ None | Unknown | ✅ Add this |
| **Depth Volume** | ❌ None | ❌ None | ⚪ Optional iOS |
| **Caching** | ⚪ Basic | ✅ Smart | ✅ Improve |
| **Offline** | ❌ None | Unknown | ⚪ Future |

---

## 🗂️ File Structure (Recommended)

```
habit_pet/
├── src/
│   ├── app/
│   │   ├── dashboard/page.tsx         (✅ Already created)
│   │   ├── add-food/page.tsx          (✅ Exists, needs update)
│   │   └── landing/page.tsx           (✅ Live on Vercel)
│   │
│   ├── components/
│   │   ├── camera/
│   │   │   ├── ProductionCamera.tsx   (Rename from FinalCameraCapture)
│   │   │   ├── BarcodeScanner.tsx     (NEW)
│   │   │   └── CameraUI.tsx           (Shared UI elements)
│   │   │
│   │   ├── food/
│   │   │   ├── FoodAnalysisResult.tsx (NEW - show AI results)
│   │   │   ├── USDASearchModal.tsx    (NEW - search modal)
│   │   │   ├── MultiFoodList.tsx      (NEW - multiple foods)
│   │   │   └── FoodSelectionModal.tsx (✅ Exists)
│   │   │
│   │   └── ui/                        (✅ Existing shadcn/ui)
│   │
│   ├── lib/
│   │   ├── services/
│   │   │   ├── FoodService.ts         (NEW - unified food service)
│   │   │   ├── USDAService.ts         (NEW - USDA API client)
│   │   │   ├── OpenFoodFactsService.ts(NEW - barcode lookups)
│   │   │   └── CacheService.ts        (NEW - smart caching)
│   │   │
│   │   ├── analyzers/
│   │   │   └── supabase.ts            (✅ Exists)
│   │   │
│   │   └── utils/
│   │       ├── imageProcessing.ts     (NEW - resize, optimize)
│   │       └── nutritionCalculator.ts (NEW - portion math)
│   │
│   └── types/
│       ├── food.ts                    (✅ Exists)
│       ├── usda.ts                    (NEW)
│       └── analyzer.ts                (✅ Exists)
│
├── supabase/
│   └── functions/
│       └── analyze_food/
│           ├── index.ts               (✅ Exists, enhance)
│           ├── priors.ts              (✅ Exists)
│           ├── multi-detect.ts        (NEW - multi-food)
│           └── barcode.ts             (NEW - barcode handler)
│
└── CalorieCameraHost/                 (⚪ Optional - fix bugs later)
```

---

## ✅ Action Plan Summary

### **Phase 1: Quick Fixes** (1 day)
- [ ] Consolidate camera components
- [ ] Improve error handling
- [ ] Add USDA search
- [ ] Enhance Supabase function

### **Phase 2: Feature Additions** (3-4 days)
- [ ] Multi-food detection
- [ ] Barcode scanning
- [ ] Smart caching
- [ ] Confidence indicators

### **Phase 3: Polish** (2-3 days)
- [ ] UX improvements
- [ ] Loading states
- [ ] Portion size hints
- [ ] Historical analysis

### **Phase 4: Advanced** (Optional, 1-2 weeks)
- [ ] Fix CalorieCameraKit bugs
- [ ] iOS native camera
- [ ] Meal planning
- [ ] Offline mode

---

## 📝 Code Migration Checklist

### From janicesc/HabitPet:
- [ ] USDA API integration logic
- [ ] Search with debouncing
- [ ] Result caching strategy
- [ ] Mock data fallback
- [ ] Error handling patterns

### From Current Project:
- [ ] Supabase `analyze_food` function
- [ ] OpenAI Vision integration
- [ ] FinalCameraCapture.tsx
- [ ] Landing page
- [ ] Dashboard UI

### New Implementations:
- [ ] Multi-food detection
- [ ] Barcode scanning
- [ ] Unified FoodService
- [ ] Smart caching layer

---

## 🎯 Success Metrics

**After Phase 1:**
- ✅ Camera works 95%+ of the time
- ✅ USDA search available as backup
- ✅ Proper error handling

**After Phase 2:**
- ✅ Can detect multiple foods in one photo
- ✅ Can scan barcodes for instant lookup
- ✅ 90%+ user satisfaction with accuracy

**After Phase 3:**
- ✅ Fast, polished UX
- ✅ Confidence indicators guide users
- ✅ Meal planning insights

---

## 💰 Cost Estimate

### API Costs:
- **OpenAI Vision** (gpt-4o-mini): ~$0.005/image = $5/1000 images
- **USDA FoodData**: FREE (1,000 requests/hour)
- **Open Food Facts**: FREE
- **Supabase**: FREE tier (50,000 requests/month)

### Development Time:
- Phase 1: 8 hours
- Phase 2: 24-32 hours
- Phase 3: 16-24 hours
- Phase 4: 40-80 hours (optional)

**Total: 48-64 hours for production-ready**

---

## 🚀 Recommended Next Step

**Start with Phase 1 - Quick Wins:**

1. Clean up camera components (30 min)
2. Add USDA search integration (2 hours)
3. Enhance error handling (1 hour)
4. Test end-to-end flow (30 min)

**Total time to working camera: ~4 hours**

Then iterate from there based on user feedback!

---

**Would you like me to start with Phase 1?** I can:
1. Consolidate the camera components
2. Port USDA integration from janicesc
3. Enhance the Supabase function
4. Get you a working camera in ~4 hours

Let me know! 🚀
