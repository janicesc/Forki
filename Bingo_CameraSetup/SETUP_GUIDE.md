# HabitPet Calorie Camera - Setup Guide

## 🚀 Quick Start

This guide will help you set up and deploy the HabitPet Calorie Camera app.

---

## Prerequisites

- **Node.js** 18+ (for web app)
- **Xcode** 15.4+ (for iOS app)
- **Supabase Account** (free tier is fine)
- **OpenAI API Key** (for AI food analysis)
- **iPhone 12 Pro+ or iPad Pro 2020+** with LiDAR (for iOS testing)

---

## 📦 Part 1: Web App Setup

### Step 1: Install Dependencies

```bash
npm install
```

### Step 2: Set Up Supabase Project

1. Go to https://supabase.com/dashboard
2. Create a new project (or use existing)
3. Wait for project to initialize (~2 minutes)
4. Go to **Settings → API**
5. Copy:
   - Project URL
   - Anon/Public key

### Step 3: Configure Environment Variables

1. Copy the example env file:
   ```bash
   cp .env.example .env.local
   ```

2. Edit `.env.local` with your values:
   ```env
   NEXT_PUBLIC_SUPABASE_URL=https://YOUR-PROJECT-ID.supabase.co
   NEXT_PUBLIC_SUPABASE_ANON_KEY=your-anon-key-here
   SUPABASE_URL=https://YOUR-PROJECT-ID.supabase.co
   SUPABASE_ANON_KEY=your-anon-key-here
   ANALYZER_CHOICE=supabase
   ```

### Step 4: Deploy Supabase Edge Function

1. Install Supabase CLI:
   ```bash
   npm install -g supabase
   ```

2. Login to Supabase:
   ```bash
   supabase login
   ```

3. Link to your project:
   ```bash
   supabase link --project-ref YOUR-PROJECT-ID
   ```

4. Get your OpenAI API key from https://platform.openai.com/api-keys

5. Deploy the Edge Function with secrets:
   ```bash
   supabase secrets set --project-ref YOUR-PROJECT-ID \
     CLASSIFIER_API_KEY="sk-proj-YOUR-OPENAI-KEY" \
     CLASSIFIER_MODEL="gpt-4o-mini" \
     CLASSIFIER_ENDPOINT="https://api.openai.com/v1/responses"
   ```

6. Deploy the function:
   ```bash
   cd supabase
   supabase functions deploy analyze_food
   cd ..
   ```

7. Verify secrets are set:
   ```bash
   supabase secrets list --project-ref YOUR-PROJECT-ID
   ```

### Step 5: Run the Web App

```bash
npm run dev
```

Open http://localhost:3000 and test the camera!

---

## 📱 Part 2: iOS App Setup

### Step 1: Update Supabase Credentials

1. Open `calorie-camera/Sources/CalorieCameraKit/UXKit/CalorieCameraView.swift`
2. Find line ~504-505
3. Update with your Supabase URL and anon key:
   ```swift
   let baseURL = "https://YOUR-PROJECT-ID.supabase.co/functions/v1"
   let apiKey = "your-anon-key-here"
   ```

### Step 2: Build and Test

1. Open the iOS demo project:
   ```bash
   open CalorieCameraHost/CalorieCameraHost.xcodeproj
   ```

2. Or test the Swift package:
   ```bash
   cd calorie-camera
   swift build
   swift test  # All 28 tests should pass
   ```

3. To test on device:
   - Connect iPhone 12 Pro+ or iPad Pro 2020+ with LiDAR
   - Select your device in Xcode
   - Run the app (⌘R)
   - Capture food photo
   - Check console for `✅ API SUCCESS!`

---

## 🌐 Part 3: Deploy to Production

### Deploy Web App to Vercel

1. Install Vercel CLI:
   ```bash
   npm install -g vercel
   ```

2. Deploy:
   ```bash
   vercel --prod
   ```

3. Add environment variables in Vercel dashboard:
   - Go to **Settings → Environment Variables**
   - Add all variables from `.env.local`
   - Make sure `ANALYZER_CHOICE=supabase`

### Deploy iOS App to App Store

1. Update bundle identifier in Xcode
2. Set up signing in Xcode (Signing & Capabilities)
3. Archive the app (Product → Archive)
4. Upload to App Store Connect
5. Submit for review

---

## 🧪 Testing Checklist

### Web App:
- [ ] Homepage loads without errors
- [ ] Camera permission works
- [ ] Can capture photo
- [ ] Food analysis returns real data (not stub)
- [ ] Check Network tab: `meta.used` contains `["supabase", "openai"]`

### iOS App:
- [ ] App builds without errors
- [ ] Camera preview shows
- [ ] Can capture photo with depth
- [ ] Food analysis returns real data
- [ ] Console shows `✅ API SUCCESS!`
- [ ] Calorie estimate displays

---

## 📊 Project Structure

```
habit_pet/
├── src/                    # Next.js web app
│   ├── app/                # App Router pages
│   ├── components/         # React components
│   └── lib/                # Utilities & analyzers
├── supabase/
│   └── functions/
│       └── analyze_food/   # Edge function for AI analysis
├── calorie-camera/         # Swift Package
│   ├── Sources/
│   │   └── CalorieCameraKit/
│   │       ├── CaptureKit/     # Camera & depth capture
│   │       ├── PerceptionKit/   # Segmentation & volume
│   │       ├── NutritionKit/    # API client
│   │       └── UXKit/           # SwiftUI views
│   └── Tests/              # Unit tests
└── CalorieCameraHost/      # iOS demo app
```

---

## 🔧 Troubleshooting

### Web App Returns Stub Data

**Problem**: `meta.used` shows `["stub"]` instead of `["supabase", "openai"]`

**Solution**:
1. Check `.env.local` has `ANALYZER_CHOICE=supabase`
2. Restart dev server: `npm run dev`
3. Clear browser cache

### Edge Function Returns 500 Error

**Problem**: Supabase function fails with "CLASSIFIER_API_KEY not configured"

**Solution**:
1. Verify secrets are set: `supabase secrets list --project-ref YOUR-PROJECT-ID`
2. Re-deploy secrets (see Step 4 above)
3. Re-deploy function: `supabase functions deploy analyze_food`

### iOS App Doesn't Build

**Problem**: Swift package build fails

**Solution**:
1. Make sure you have Xcode 15.4+
2. Run `swift build` in `calorie-camera/` directory
3. Check for any error messages

### iOS App Returns Fake Data

**Problem**: Console shows stub data instead of real API response

**Solution**:
1. Check `CalorieCameraView.swift` has correct Supabase URL
2. Verify Edge Function is deployed: `supabase functions list`
3. Check device has internet connection
4. Look for error logs in Xcode console

### Volume Estimation Returns 0.0 mL

**Problem**: iOS app shows 0 calories

**Solution**:
1. Make sure you're using a physical device (not simulator)
2. Device must have LiDAR (iPhone 12 Pro+ or iPad Pro 2020+)
3. Point camera at food on a plate/table (needs flat background)
4. Hold device ~40-50cm away from food

---

## 🛡️ Security Notes

**Important**:
- ✅ `.env.local` is gitignored (don't commit it!)
- ✅ Supabase anon key is safe for client-side (public)
- ✅ OpenAI API key is only in Supabase Edge Function (secure)
- ⚠️ iOS app has hardcoded credentials (consider using Info.plist for production)

**Best Practices**:
- Rotate OpenAI API key periodically
- Set up Supabase Row Level Security policies
- Use environment variables for all secrets
- Enable Supabase's built-in rate limiting

---

## 📚 Additional Documentation

- [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) - Current deployment status and known issues
- [CAMERA_INTEGRATION_PLAN.md](CAMERA_INTEGRATION_PLAN.md) - Technical integration details
- [QUICK_LINKS.md](QUICK_LINKS.md) - Quick reference links
- [LANDING_PAGE_DEPLOYMENT.md](LANDING_PAGE_DEPLOYMENT.md) - Landing page info

---

## 🆘 Getting Help

If you run into issues:

1. Check the [Troubleshooting](#-troubleshooting) section above
2. Review [DEPLOYMENT_STATUS.md](DEPLOYMENT_STATUS.md) for known issues
3. Check Supabase logs: `supabase functions logs analyze_food`
4. Check browser console for errors (F12)
5. Check Xcode console for iOS errors

---

## ✅ What's Been Fixed

All critical bugs have been fixed:
- ✅ Volume estimation now works correctly
- ✅ Camera intrinsics properly extracted
- ✅ Vision framework segmentation integrated
- ✅ Web app connects to real AI (not stub)
- ✅ Supabase Edge Function has all credentials
- ✅ iOS app properly configured
- ✅ All 28 Swift tests passing

**The app is ready to use!** 🎉
