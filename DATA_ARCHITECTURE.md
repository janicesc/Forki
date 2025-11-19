# Data Architecture Guide

## Overview

This document explains how user data is stored and managed in the Forki app. We use a **two-table architecture** that separates authentication from application data.

## Table Structure

### 1. `auth.users` (Supabase Auth - Managed by Supabase)
**Purpose:** Authentication only
- `id` (UUID) - Primary key
- `email` - User's email address
- `encrypted_password` - Hashed password (managed by Supabase)
- `user_metadata` - JSON metadata (e.g., name from signup)
- `created_at`, `updated_at` - Timestamps

**Key Points:**
- ✅ Managed entirely by Supabase Auth
- ✅ Never directly modified by our app
- ✅ Used only for signup, sign-in, password reset
- ✅ Automatically creates user on signup

### 2. `public.users` (Our Application Data Table)
**Purpose:** Single source of truth for ALL application data

**Stored Data:**
- **Basic Profile:**
  - `id` (UUID, FK to `auth.users.id`)
  - `name` - User's name
  - `email` - User's email (duplicated for convenience)
  
- **Biometrics:**
  - `age` - User's age
  - `gender` - User's gender
  - `height` - User's height
  - `weight` - User's weight
  - `bmi` - Calculated BMI
  
- **Goals & Preferences:**
  - `goal` - User's fitness/health goal
  - `goal_duration` - Duration in days
  - `food_preferences` - Array of dietary preferences
  - `notifications` - Notification preferences
  - `selected_character` - Selected avatar/character
  
- **Wellness Snapshot System:**
  - `persona_id` - ID of the wellness persona (1-13)
  - `recommended_calories` - Daily calorie recommendation
  - `eating_pattern` - Recommended eating pattern
  - `body_type` - Body type classification
  - `metabolism` - Metabolism type
  
- **Macros:**
  - `macro_protein` - Recommended protein (grams)
  - `macro_carbs` - Recommended carbs (grams)
  - `macro_fats` - Recommended fats (grams)
  - `macro_fiber` - Recommended fiber (grams)
  
- **Timestamps:**
  - `created_at` - When profile was created
  - `updated_at` - Last update time (auto-updated)

**Key Points:**
- ✅ **Single source of truth** for all app data
- ✅ Automatically created when user signs up (via database trigger)
- ✅ Protected by Row Level Security (RLS) - users can only access their own data
- ✅ All data loaded from here on sign-in

## Data Flow

### Sign Up Flow
1. User fills signup form (name, email, password)
2. `SupabaseAuthService.signUp()` creates user in `auth.users`
3. Database trigger automatically creates row in `public.users` with:
   - `id` = user's auth ID
   - `email` = user's email
   - `name` = from `user_metadata` (if available)
4. App calls `saveUserData()` to update `public.users` with name
5. User proceeds to onboarding
6. Onboarding data is saved to `public.users` via `saveUserData()`

### Sign In Flow
1. User enters email and password
2. `SupabaseAuthService.signIn()` authenticates with `auth.users`
3. Session token is saved locally
4. `loadUserData()` fetches ALL data from `public.users` using session token
5. App restores:
   - Profile data (name, age, gender, etc.)
   - Biometrics (height, weight, BMI)
   - Wellness snapshot (persona_id, recommended_calories, etc.)
   - Macros (protein, carbs, fats, fiber)
   - Preferences (food preferences, notifications, character)
6. `userData.nutrition.initializeFromSnapshot()` restores avatar state
7. User navigates to Home Screen with full data restored

### App Launch Flow
1. App checks if user is signed in (`hp_isSignedIn`)
2. If signed in, loads session from UserDefaults
3. Calls `loadUserData()` with session token
4. Restores all user data from `public.users`
5. Initializes nutrition state with persona and calories
6. User sees Home Screen with their data

## Why Two Tables?

### Benefits:
1. **Separation of Concerns:**
   - Auth table handles authentication (passwords, sessions)
   - Profile table handles application data (wellness, preferences)

2. **Security:**
   - Auth table is managed by Supabase (secure, tested)
   - Profile table has RLS policies for data protection
   - Can't accidentally expose sensitive auth data

3. **Flexibility:**
   - Can add/remove profile fields without affecting auth
   - Can query profile data independently
   - Can implement soft deletes, data versioning, etc.

4. **Standard Practice:**
   - This is the recommended Supabase pattern
   - Used by most production apps
   - Well-documented and supported

### Not Complicated:
- ✅ Only ONE table to manage (`public.users`)
- ✅ `auth.users` is managed automatically by Supabase
- ✅ Database trigger handles sync automatically
- ✅ Single `loadUserData()` call loads everything
- ✅ Single `saveUserData()` call saves everything

## Data Storage Locations

### Supabase (`public.users` table)
**Stored:** All persistent user data
- Profile information
- Biometrics
- Wellness snapshot
- Macros
- Preferences

### Local Storage (UserDefaults)
**Stored:** Session and quick-access data
- `supabase_access_token` - Session token
- `supabase_refresh_token` - Refresh token
- `supabase_user_id` - User ID
- `hp_userEmail` - Email (for quick access)
- `hp_userName` - Name (for quick access)
- `hp_personaID` - Persona ID (for quick access)
- `hp_recommendedCalories` - Calories (for quick access)
- `hp_isSignedIn` - Sign-in status
- `hp_hasOnboarded` - Onboarding status

**Note:** UserDefaults is used for:
- Session management (tokens)
- Quick access to frequently used data
- App state (signed in, onboarded)
- **NOT** the source of truth - always sync with Supabase

## Best Practices

1. **Always load from Supabase on sign-in:**
   - Don't rely on UserDefaults for data
   - Always call `loadUserData()` after authentication
   - UserDefaults is for session/state only

2. **Save to Supabase after changes:**
   - After onboarding completion
   - After profile updates
   - After wellness snapshot changes
   - Use `saveUserData()` or `updateUserData()`

3. **Use session tokens:**
   - Always pass session token to `loadUserData()` and `saveUserData()`
   - Required for RLS policies to work
   - Stored in UserDefaults after sign-in

4. **Handle missing data gracefully:**
   - If `loadUserData()` returns `nil`, user might be new
   - Use default values
   - Prompt user to complete onboarding

## Summary

- **`auth.users`** = Authentication (email, password) - Managed by Supabase
- **`public.users`** = All application data - Managed by our app
- **Single source of truth:** `public.users` table
- **On sign-in:** Load everything from `public.users`
- **On changes:** Save to `public.users`
- **Not complicated:** Only one table to manage, trigger handles sync

