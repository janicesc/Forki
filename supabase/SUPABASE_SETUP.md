# Supabase Authentication Setup Guide

This guide explains how to set up Supabase authentication and user data storage for the Forki app.

## Overview

The app now uses Supabase for:
- User authentication (sign up and sign in)
- Storing user profile data
- Restoring user sessions and avatar state

## Database Setup

### 1. Run the Migration

To create the `users` table in your Supabase database, run the migration file:

```bash
# If using Supabase CLI locally
supabase db push

# Or apply the migration manually via Supabase Dashboard:
# 1. Go to SQL Editor in your Supabase Dashboard
# 2. Copy the contents of supabase/migrations/20250111000000_create_users_table.sql
# 3. Run the SQL script
```

The migration creates:
- A `public.users` table with all user profile fields
- Row Level Security (RLS) policies for data access
- An automatic `updated_at` timestamp trigger
- An index on email for faster lookups

### 2. Verify Table Creation

After running the migration, verify the table exists:
- Go to Supabase Dashboard → Table Editor
- You should see a `users` table in the `public` schema

## Authentication Flow

### Sign Up
1. User enters name, username (email), and password
2. App creates user in Supabase Auth
3. User data is saved locally (as before)
4. User is directed to Onboarding Flow
5. After onboarding, user data is saved to Supabase `users` table
6. User lands on Home Screen with their data applied

### Sign In
1. User enters username and password
2. App authenticates with Supabase
3. If credentials are invalid:
   - Shows "Incorrect password. Try again?" for wrong password
   - Shows "No account found with this username. Want to sign up?" for non-existent user
4. On success, loads user data from Supabase
5. Restores avatar state and session
6. Directs to Home Screen with user data applied

## Configuration

The Supabase configuration is in `SupabaseAuthService.swift`:
- **Supabase URL**: `https://uisjdlxdqfovuwurmdop.supabase.co`
- **API Key**: Already configured (anon key)

If you need to change these, update the constants in `SupabaseAuthService.swift`.

## Data Storage

User data is stored in two places:
1. **Supabase `users` table**: Primary storage for user profiles
2. **UserDefaults**: Local cache for offline access and faster loading

The app syncs data between both locations to ensure:
- Data persists across devices (via Supabase)
- Fast local access (via UserDefaults)
- Offline functionality (uses local data if Supabase is unavailable)

## Testing

To test the authentication:

1. **Sign Up**:
   - Enter a new username/email and password
   - Complete onboarding
   - Verify data is saved to Supabase

2. **Sign In**:
   - Use existing credentials
   - Verify user data loads from Supabase
   - Verify avatar state is restored

3. **Error Handling**:
   - Try signing in with non-existent username
   - Try signing in with wrong password
   - Verify appropriate error messages appear

## Troubleshooting

### "Failed to save user data to Supabase"
- Check that the `users` table exists
- Verify RLS policies are set correctly
- Check Supabase logs for errors

### "Failed to load user data from Supabase"
- Verify the user ID is stored in UserDefaults
- Check network connectivity
- Verify the user exists in the `users` table

### Authentication errors
- Verify Supabase URL and API key are correct
- Check Supabase Auth is enabled in dashboard
- Verify email confirmation is disabled (or handle confirmation flow)

## Security Notes

- Row Level Security (RLS) is enabled on the `users` table
- Users can only read/update their own data
- The API key used is the anon key (safe for client-side use)
- Passwords are hashed by Supabase Auth (never stored in plain text)

## Next Steps

1. Run the database migration
2. Test sign up and sign in flows
3. Verify data persistence across app restarts
4. Test error handling scenarios

