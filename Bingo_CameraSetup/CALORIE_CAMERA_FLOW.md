# Calorie Camera Flow: From "Scan Food" to Food Logger View

## Complete Logic Outline

### 1. **User Interaction: "Scan Food" Button**
   - **Location**: `CalorieCameraView.swift` (line 178)
   - **Action**: Calls `coordinator.startCapture()`
   - **State**: Changes from `.ready` → `.capturing`

---

### 2. **Capture Quality Gate** (V2 Feature)
   - **Location**: `CalorieCameraView.swift` → `performQualityGate()` (line 399)
   - **Purpose**: Ensures camera has enough depth/parallax data
   - **Process**:
     - Evaluates tracking state, parallax, and depth coverage
     - Shows progress bar: "Move around the plate to hit quality threshold"
     - Continues until quality threshold met OR timeout
   - **Output**: `CaptureQualityStatus` (shouldStop flag)

---

### 3. **Frame Capture** (V2 Temporal Fusion)
   - **Location**: `CalorieCameraView.swift` → `capture()` (line 406-420)
   - **Process**:
     - Captures **3 frames** sequentially (for temporal smoothing)
     - Each frame includes:
       - RGB image (JPEG data)
       - Depth map (LiDAR or SfM)
       - Camera intrinsics
   - **V2 Improvement**: Multiple frames enable EMA (Exponential Moving Average) smoothing

---

### 4. **Backend API Call: Dual Analyzer Client**
   - **Location**: `CalorieCameraView.swift` → `capture()` (line 427-457)
   - **Status Message**: "Calling API..."
   
   #### **4a. Primary: Next.js API** (if configured)
   - **URL**: `NEXTJS_API_URL/api/analyze-food` (from environment variable)
   - **Method**: POST
   - **Payload**: 
     ```json
     {
       "imageBase64": "<base64-encoded JPEG>"
     }
     ```
   - **Response Format**: Next.js-specific format
   - **If fails**: Falls back to Supabase

   #### **4b. Fallback: Supabase Edge Function**
   - **URL**: `https://uisjdlxdqfovuwurmdop.supabase.co/functions/v1/analyze_food`
   - **Method**: POST
   - **Headers**:
     - `Content-Type: application/json`
     - `apikey: <supabase-anon-key>`
     - `Authorization: Bearer <supabase-anon-key>`
   - **Payload**:
     ```json
     {
       "imageBase64": "<base64-encoded JPEG>",
       "mimeType": "image/jpeg"
     }
     ```
   - **Backend Processing** (`supabase/functions/analyze_food/index.ts`):
     1. Receives base64 image
     2. Uploads to Supabase Storage (`ai-uploads` bucket) → gets public URL
     3. Calls **OpenAI GPT-4o-mini** Vision API with:
        - Image URL (faster than base64)
        - Prompt: Analyze food, estimate calories, identify food type
        - Model: `gpt-4o-mini` (faster than gpt-4o)
        - Max tokens: 300
        - Response format: JSON
     4. Parses OpenAI response:
        - Food label/name
        - Estimated calories (mean)
        - Uncertainty (sigma)
        - Food priors (density, energy density) if available
     5. Returns JSON response:
        ```json
        {
          "items": [{
            "label": "apple",
            "calories": 95,
            "sigmaCalories": 10,
            "priors": {
              "density": { "mu": 0.85, "sigma": 0.10 },
              "kcalPerG": { "mu": 1.30, "sigma": 0.05 }
            }
          }],
          "meta": { "used": ["openai"] }
        }
        ```

   #### **4c. API Response Processing**
   - **Location**: `DualAnalyzerClient.swift` → `parseResponse()`
   - **Output**: `AnalyzerObservation` containing:
     - `label`: Food name
     - `calories`: Mean calories (Supabase) or upper bound (Next.js)
     - `sigmaCalories`: Uncertainty
     - `priors`: Food density & energy density priors
     - `evidence`: Analysis method tags
     - `path`: Which API was used

---

### 5. **Geometry Estimation (V2)**
   - **Location**: `CalorieCameraView.swift` → `capture()` (line 459-486)
   - **Component**: `GeometryEstimatorV2`
   - **Process**:
     1. **Temporal Fusion**: Processes all 3 captured frames
        - Uses EMA (Exponential Moving Average) to smooth:
          - Area fraction (food pixels)
          - Median depth
          - Height estimates
     2. **Robust Statistics**: Uses median/IQR instead of mean/std
        - Outlier-resistant calculations
        - Height band detection using IQR multipliers
     3. **Volume Calculation**:
        - Estimates food area from depth map
        - Calculates height from depth differences
        - Volume = area × height (in mL)
     4. **Soft Validation**: Plausibility scores (not hard rejections)
        - Checks if height/volume are reasonable
        - Adjusts uncertainty if implausible
   - **Output**: `GeometryEstimate`
     - `label`: "geometry" (fallback)
     - `volumeML`: Estimated volume
     - `calories`: Calculated from volume × density × energy
     - `sigma`: Uncertainty from error propagation

---

### 6. **Fusion: Combine API + Geometry**
   - **Location**: `CalorieCameraView.swift` → `capture()` (line 488-491)
   - **Component**: `AnalyzerRouter` / `FusionEngine`
   - **Process**:
     - Combines `analyzerObservation` (from API) + `geometryEstimate` (from depth)
     - Uses precision-weighted fusion (inverse variance weighting)
     - Calculates fused calories and uncertainty
   - **Output**: `FusionResult`
     - `fusedCalories`: Combined estimate
     - `fusedSigma`: Combined uncertainty
     - `evidence`: ["analyzer", "geometry", etc.]

---

### 7. **Upper Bound Calculation**
   - **Location**: `CalorieCameraView.swift` → `capture()` (line 499-518)
   - **Purpose**: Display conservative estimate (mean + 2×sigma)
   - **Logic**:
     - **If Next.js API**: Calories already upper bound → use directly
     - **If Supabase API**: Calories is mean → calculate `mean + 2×sigma`
     - **If geometry-only**: Calculate `mean + 2×sigma`
   - **Result**: `upperBound` stored in `result.total.mu`

---

### 8. **Final Result Creation**
   - **Location**: `CalorieCameraView.swift` → `capture()` (line 520-532)
   - **Creates**: `CalorieResult`
     ```swift
     CalorieResult(
       items: [ItemEstimate(
         label: finalLabel,           // From API or "geometry"
         volumeML: geometryEstimate.volumeML,
         calories: upperBound,        // Upper bound (mean + 2×sigma)
         sigma: finalSigma,
         evidence: ["analyzer", "geometry"]
       )],
       total: (mu: upperBound, sigma: finalSigma)
     )
     ```

---

### 9. **Value of Information (VoI) Check** (Optional)
   - **Location**: `CalorieCameraView.swift` → `capture()` (line 559-566)
   - **Condition**: If uncertainty too high (`totalRelativeUncertainty >= voiThreshold`)
   - **Action**: Asks user binary question (e.g., "Is the dish cream-based?")
   - **If VoI needed**: State → `.awaitingVoI`, waits for user response
   - **If VoI not needed**: Proceeds to `finish()`

---

### 10. **Finish & Callback**
   - **Location**: `CalorieCameraView.swift` → `finish()` (line 569-579)
   - **Action**: Calls `onResult(result)`
   - **State**: `.completed`
   - **Status**: "Capture complete."

---

### 11. **Bridge Conversion**
   - **Location**: `CalorieCameraBridge.swift` → `onResult` (line 88-99)
   - **Process**:
     1. Receives `CalorieResult` from CalorieCameraKit
     2. Converts to `AICameraNutritionResult`:
        - Extracts label, calories, volume
        - **Calculates macros heuristically** (since V2 doesn't provide macros):
          - Protein: `(calories × 0.25) / 4.0` (25% of calories, 4 kcal/g)
          - Carbs: `(calories × 0.45) / 4.0` (45% of calories, 4 kcal/g)
          - Fats: `(calories × 0.30) / 9.0` (30% of calories, 9 kcal/g)
        - Applies safety caps (max 200g protein, 300g carbs, 200g fats)
     3. Calls `onComplete(.success(converted, sourceType: .camera))`
     4. Dismisses camera view

---

### 12. **HomeScreen Processing**
   - **Location**: `HomeScreen.swift` → `CalorieCameraBridge` callback (line 130-265)
   - **Process**:
     1. Receives `AICameraNutritionResult`
     2. **USDA Lookup** (async):
        - Searches USDA database for food name
        - If match found: Uses USDA standard serving size (100-150g depending on category)
        - If no match: Uses AI-provided macros (from bridge)
     3. Creates `FoodItem` with:
        - Name: From API or "Detected Food"
        - Calories: From API (capped at 2000)
        - Macros: From USDA (if match) or AI heuristics
     4. Sets `aiPrefill = FoodItem(...)`
     5. **Sets `showFoodLogger = true`** ← **This was missing! (Now fixed)**

---

### 13. **Food Logger View Display**
   - **Location**: `HomeScreen.swift` → `.sheet(isPresented: $showFoodLogger)` (line 272)
   - **View**: `FoodLoggerView`
   - **Prefill**: Uses `aiPrefill` to populate:
     - Food name
     - Calories
     - Protein, carbs, fats
   - **User can**:
     - Adjust serving size
     - Edit nutrition values
     - Save to log
     - Cancel

---

## Backend Endpoints Summary

### **Primary: Next.js API** (Optional)
- **URL**: `NEXTJS_API_URL/api/analyze-food`
- **When used**: If `NEXTJS_API_URL` environment variable is set
- **Format**: Next.js-specific JSON

### **Fallback: Supabase Edge Function** (Always available)
- **URL**: `https://uisjdlxdqfovuwurmdop.supabase.co/functions/v1/analyze_food`
- **Function**: `supabase/functions/analyze_food/index.ts`
- **AI Model**: OpenAI GPT-4o-mini Vision API
- **Storage**: Supabase Storage (`ai-uploads` bucket)
- **Response**: Standard JSON format with food analysis

---

## Key V2 Improvements

1. **Temporal Fusion**: Multiple frames → EMA smoothing → more stable estimates
2. **Robust Statistics**: Median/IQR → outlier-resistant calculations
3. **Soft Validation**: Plausibility scores instead of hard rejections
4. **Dual Analyzer**: Next.js (primary) → Supabase (fallback) chain
5. **Upper Bound Display**: Always shows conservative estimate (mean + 2×sigma)

---

## Data Flow Diagram

```
User taps "Scan Food"
    ↓
Capture 3 frames (temporal fusion)
    ↓
Call DualAnalyzerClient
    ├─→ Try Next.js API (if configured)
    │   └─→ If fails → Supabase
    └─→ Supabase Edge Function
        └─→ Upload image to Storage
        └─→ Call OpenAI GPT-4o-mini
        └─→ Return food analysis
    ↓
GeometryEstimatorV2 processes frames
    ├─→ Temporal fusion (EMA)
    ├─→ Robust statistics (median/IQR)
    └─→ Volume estimation
    ↓
FusionEngine combines API + Geometry
    ↓
Calculate upper bound (mean + 2×sigma)
    ↓
Create CalorieResult
    ↓
Call onResult() → CalorieCameraBridge
    ↓
Convert to AICameraNutritionResult
    ├─→ Calculate macros heuristically
    └─→ Apply safety caps
    ↓
Call onComplete() → HomeScreen
    ↓
USDA lookup (async)
    ├─→ If match: Use USDA data
    └─→ If no match: Use AI macros
    ↓
Set aiPrefill + showFoodLogger = true
    ↓
FoodLoggerView appears with pre-filled data
```

---

## Debug Logging Points

- `📸 [V2] Captured frame X/3` - Frame capture
- `🔄 Making API call to analyzer...` - API call start
- `🔄 [DualAnalyzer] Trying Next.js API first...` - Next.js attempt
- `🔄 [DualAnalyzer] Using Supabase Edge Function fallback...` - Supabase fallback
- `✅ API SUCCESS!` - API success
- `📊 [UpperBound]` - Upper bound calculation
- `✅ [CalorieCamera] Calling onResult` - Result callback
- `📸 [Bridge] Received result` - Bridge conversion
- `🏠 [HomeScreen] Camera success` - HomeScreen processing

