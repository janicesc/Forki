//
//  HomeScreen.swift
//  Forki
//

import SwiftUI
import Combine
import CalorieCameraKit   // if not already imported by your bridge

// MARK: - Custom Smooth Transition
extension AnyTransition {
    static var smoothTransition: AnyTransition {
        .asymmetric(
            insertion: .scale(scale: 0.9).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
        )
        .animation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0))
    }
}

struct HomeScreen: View {
    // Shared nutrition/progress state
    @EnvironmentObject var nutrition: NutritionState
    @EnvironmentObject var userData: UserData
    
    // Avatar celebration state
    @State private var celebrating = false

    // Other UI state
    @State private var showFoodLogger = false
    @State private var showFeedingEffect = false
    @State private var showRecipes = false
    @State private var currentScreen: Int = 6
    @State private var showStats = false
    @State private var showProfile = false
    @State private var showAICamera = false
    @State private var showExplore = false
    @State private var aiPrefill: FoodItem? = nil
    // USDA lookup removed - V2 Calorie Camera API provides all nutrition data
    
    let loggedFoods: [LoggedFood]   // initial payload you were passing in
    var onSignOut: (() -> Void)  // Callback to navigate to Sign Up screen
    
    init(loggedFoods: [LoggedFood] = [], onSignOut: @escaping (() -> Void) = {}) {
        self.loggedFoods = loggedFoods
        self.onSignOut = onSignOut
    }
    
    // Initialize avatar from snapshot if needed
    private func initializeAvatarIfNeeded() {
        guard UserDefaults.standard.bool(forKey: "hp_avatarNeedsInitialization") else {
            return
        }
        
        let personaID = UserDefaults.standard.integer(forKey: "hp_personaID")
        let recommendedCalories = UserDefaults.standard.integer(forKey: "hp_recommendedCalories")
        
        // Only initialize if we have valid data
        if personaID > 0 && recommendedCalories > 0 {
            nutrition.initializeFromSnapshot(
                personaID: personaID,
                recommendedCalories: recommendedCalories
            )
        }
        
        // Mark as initialized
        UserDefaults.standard.set(false, forKey: "hp_avatarNeedsInitialization")
    }

    // Derived
    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        else if hour < 18 { return "Good afternoon" }
        return "Good evening"
    }
    
    private var petMoodText: String {
        switch nutrition.avatarState {
        case .starving:
                return "Feed me…"
            case .sad:
                return "I’m hungry!"
            case .neutral:
                return "I’m here with you!"
            case .happy:
                return "Yum! Feeling good!"
            case .strong:
                return "Powered up!"
            case .overfull:
                return "I'm stuffed…"
            case .bloated:
                return "Too much…"
            case .dead:
                return "I need your help…"
            }
        }

    var body: some View {
        ZStack {
            // Background gradient (FORKI_Game)
            ForkiTheme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
                        avatarStage
                        primaryActions
                        caloriesProgressCard
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 10)
                    .padding(.bottom, 160)
                }
                
                Spacer(minLength: 0)
                
                // Bottom Navigation Bar - docked to bottom safe area
                bottomBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)
                    .background(ForkiTheme.panelBackground.ignoresSafeArea(edges: .bottom))
            }
            .overlay(
                // Purple outline around the container
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(ForkiTheme.borderPrimary, lineWidth: 4)
                    .ignoresSafeArea()
            )
        }
        .onReceive(SparkleEventBus.shared.sparklePublisher) { event in
            if event == .purpleConfetti {
                celebrating = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    celebrating = false
                }
            }
        }
        .onAppear {
            // Initialize avatar from snapshot if needed (after onboarding)
            initializeAvatarIfNeeded()
        }
        // AI Camera
        .sheet(isPresented: $showAICamera) {
            CalorieCameraBridge { output in
                NSLog("🏠 [HomeScreen] Received camera output")
                switch output {
                case .success(let res, _):
                    NSLog("🏠 [HomeScreen] Camera success: \(res.label), \(Int(res.cFused)) kcal")
                    // 👇 Always update UI on main thread
                    DispatchQueue.main.async {
                        let name = res.label.trimmingCharacters(in: .whitespacesAndNewlines)
                        // one-decimal rounding helper inline
                        func r1(_ x: Double?) -> Double {
                            let v = x ?? 0
                            if v.isNaN || v.isInfinite { return 0 }
                            return (round(v * 10) / 10)
                        }
                        let labelForSearch = name.lowercased()
                        
                        // Nutrition thresholds
                        let maxCalories = 2000
                        let maxProtein = 200.0
                        let maxCarbs   = 300.0
                        let maxFats    = 200.0

                        // Dismiss camera sheet first
                        showAICamera = false

                        // Set AI prefill IMMEDIATELY (before USDA lookup) so user sees detected food right away
                        let cals = min(max(0, Int(res.cFused.rounded())), maxCalories)
                        var p = r1(res.protein)
                        var c = r1(res.carbs)
                        var f = r1(res.fats)
                        p = min(p, maxProtein)
                        c = min(c, maxCarbs)
                        f = min(f, maxFats)
                        
                        // DEBUG: Log what we're setting
                        NSLog("📊 [HomeScreen] Setting prefill with name: '\(name)' (isEmpty: \(name.isEmpty))")
                        NSLog("📊 [HomeScreen] Full result: label='\(res.label)', cFused=\(res.cFused), protein=\(res.protein ?? 0), carbs=\(res.carbs ?? 0), fats=\(res.fats ?? 0)")
                        
                        let finalName = name.isEmpty ? "Detected Food" : name
                        NSLog("📊 [HomeScreen] Final name being used: '\(finalName)'")
                        
                        // CRITICAL: Set aiPrefill FIRST, then show sheet on next run loop
                        // This ensures the sheet is created with the prefill already set
                        let prefillItem = FoodItem(
                            id: Int.random(in: 1000...9999),
                            name: finalName,
                            calories: cals,
                            protein: p,
                            carbs:   c,
                            fats:    f,
                            category: "Detected",
                            usdaFood: nil
                        )
                        
                        // Set prefill synchronously
                        aiPrefill = prefillItem
                        NSLog("📊 [HomeScreen] Set AI prefill: name='\(finalName)', calories=\(cals) kcal")
                        print("📊 [HomeScreen] Set AI prefill: name='\(finalName)', calories=\(cals) kcal")
                        
                        // Show food logger on next run loop to ensure prefill is set
                        DispatchQueue.main.async {
                            // Double-check prefill is set before showing
                            if aiPrefill != nil {
                                showFoodLogger = true
                                NSLog("📊 [HomeScreen] Showed food logger with AI prefill (async)")
                                print("📊 [HomeScreen] Showed food logger with AI prefill (async)")
                            } else {
                                NSLog("⚠️ [HomeScreen] WARNING: aiPrefill is nil when trying to show food logger!")
                                print("⚠️ [HomeScreen] WARNING: aiPrefill is nil when trying to show food logger!")
                            }
                        }
                    
                    // NOTE: USDA lookup removed - V2 Calorie Camera API already provides
                    // accurate nutrition data (label, calories, macros) that matches the
                    // actual portion size detected. USDA lookup was redundant and caused
                    // issues (e.g., matching "Orange Juice" instead of "Orange").
                    }

                case .failed(let error):
                    print("🔍 Failed: \(error)")

                case .cancelled:
                    print("🔍 Cancelled")
                    // no prefill retained on cancel
                    aiPrefill = nil
                }
            }
        }
        // Food logger
        // CRITICAL: Only show sheet when showFoodLogger is true AND (aiPrefill exists OR it's a manual log)
        .sheet(isPresented: Binding(
            get: { showFoodLogger },
            set: { newValue in
                showFoodLogger = newValue
                // Clear prefill when sheet is dismissed (unless it's a manual log)
                if !newValue && aiPrefill != nil {
                    // Don't clear immediately - let onClose handle it
                }
            }
        )) {
            FoodLoggerView(
                prefill: aiPrefill,
                loggedMeals: nutrition.loggedMeals,
                onSave: { loggedFood in
                    nutrition.add(loggedFood)        // ✅ single source of truth
                    showFeedingEffect = true
                    showFoodLogger = false
                    aiPrefill = nil                   // clear detected prefill after save
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showFeedingEffect = false
                    }
                },
                onClose: {
                    showFoodLogger = false
                    aiPrefill = nil                   // clear detected prefill after cancel
                },
                onDeleteFromHistory: { id in
                    nutrition.remove(id)
                },
                editId: nil,
                onUpdate: { id, loggedFood in
                    nutrition.update(id, with: loggedFood)
                }
            )
            .presentationDetents([.fraction(0.6), .large])
            .presentationDragIndicator(.visible)
        }
        
        // Recipes sheet
        .sheet(isPresented: $showRecipes) {
            RecipesView(
                currentScreen: $currentScreen,
                loggedFoods: $nutrition.loggedMeals,
                onFoodLogged: { loggedFood in
                    // Add to nutrition state to update calories, macros, avatar state, and battery
                    nutrition.add(loggedFood)
                    showFeedingEffect = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        showFeedingEffect = false
                    }
                },
                userData: userData,
                onDismiss: {
                    showRecipes = false
                },
                onHome: {
                    showRecipes = false
                },
                onExplore: {
                    showRecipes = false
                    showExplore = true
                },
                onCamera: {
                    showRecipes = false
                    showAICamera = true
                },
                onProgress: {
                    showRecipes = false
                    showStats = true
                },
                onProfile: {
                    showRecipes = false
                    showProfile = true
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        
        // Stats overlay
        .overlay {
            if showStats {
                ProgressScreen(
                    userData: userData,
                    nutrition: nutrition,
                    onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showStats = false
                        }
                    },
                    onHome: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showStats = false
                        }
                    },
                    onExplore: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showStats = false
                            showExplore = true
                        }
                    },
                    onCamera: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showStats = false
                            showAICamera = true
                        }
                    },
                    onProfile: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showStats = false
                            showProfile = true
                        }
                    }
                )
                .zIndex(1)
            }
        }
        // Explore screen
        .overlay {
            if showExplore {
                RestaurantListView(
                    onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showExplore = false
                        }
                    },
                    onLogFood: { foodItem in
                        // Convert to LoggedFood and add to nutrition state
                        let loggedFood = LoggedFood(
                            food: foodItem,
                            portion: 1.0,
                            timestamp: Date()
                        )
                        nutrition.add(loggedFood)
                        
                        // Dismiss all sheets/overlays and return to Home Screen
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showExplore = false
                        }
                        
                        // Trigger feeding animation
                        showFeedingEffect = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            showFeedingEffect = false
                        }
                    },
                    onHome: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showExplore = false
                        }
                    },
                    onProgress: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showExplore = false
                            showStats = true
                        }
                    },
                    onProfile: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showExplore = false
                            showProfile = true
                        }
                    },
                    onCamera: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showExplore = false
                            showAICamera = true
                        }
                    }
                )
                .zIndex(1)
            }
        }
        .overlay {
            if showProfile {
                // Capture onSignOut callback to avoid closure recursion
                let signOutCallback = onSignOut
                
                ProfileScreen(
                    userData: userData,
                    nutrition: nutrition,
                    onDismiss: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showProfile = false
                        }
                    },
                    onHome: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showProfile = false
                        }
                    },
                    onExplore: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showProfile = false
                            showExplore = true
                        }
                    },
                    onCamera: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showProfile = false
                            showAICamera = true
                        }
                    },
                    onProgress: {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showProfile = false
                            showStats = true
                        }
                    },
                    onRetakeQuiz: {
                        // Navigate back to onboarding quiz
                        // This would typically be handled at a higher level
                        // For now, we'll just show an alert or navigate
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showProfile = false
                        }
                        // Note: To actually retake quiz, you'd need to reset onboarding state
                        // and navigate to OnboardingFlow from ForkiFlow
                    },
                    onSignOut: {
                        // Sign out user - clear local session state only
                        // User data remains in Supabase database and will be restored on sign in
                        UserDefaults.standard.set(false, forKey: "hp_isSignedIn")
                        UserDefaults.standard.set(false, forKey: "hp_hasOnboarded")
                        // Note: We keep user data in UserDefaults for potential quick restore,
                        // but clear the sign-in flag so user must authenticate again
                        
                        // Clear Supabase session (authentication only, data remains in database)
                        SupabaseAuthService.shared.clearSession()
                        
                        // Clear in-memory user data for privacy (data still saved in Supabase)
                        userData.name = ""
                        userData.email = ""
                        userData.age = ""
                        userData.gender = ""
                        userData.height = ""
                        userData.weight = ""
                        userData.goal = ""
                        userData.personaID = 0
                        userData.recommendedCalories = 0
                        
                        // Clear in-memory nutrition state for privacy (data still saved in Supabase)
                        nutrition.loggedMeals = []
                        nutrition.caloriesCurrent = 0
                        nutrition.proteinCurrent = 0
                        nutrition.carbsCurrent = 0
                        nutrition.fatsCurrent = 0
                        
                        // Close profile screen
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            showProfile = false
                        }
                        
                        // Navigate to Sign Up screen (empty, ready for new sign up or sign in)
                        // When user signs in again, their data will be loaded from Supabase
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            signOutCallback()
                        }
                    },
                    onPrivacyPolicy: {
                        // Open Privacy Policy - could be a web view or sheet
                        if let url = URL(string: "https://example.com/privacy-policy") {
                            UIApplication.shared.open(url)
                        }
                    },
                    onTermsConditions: {
                        // Open Terms & Conditions - could be a web view or sheet
                        if let url = URL(string: "https://example.com/terms-conditions") {
                            UIApplication.shared.open(url)
                        }
                    }
                )
                .zIndex(1)
            }
        }
        
        // Keep avatar/video in sync with numbers even if updated elsewhere
        .onChange(of: nutrition.caloriesCurrent) { _, _ in /* avatar auto-updates inside model */ }
        // If you target iOS 17+, you can optionally use the two-arg form:
        // .onChange(of: nutrition.caloriesCurrent) { oldValue, newValue in }

        .onAppear {
            // Seed with any preexisting logs passed in
            if !loggedFoods.isEmpty {
                nutrition.replaceAll(with: loggedFoods)   // make sure this exists on NutritionState
            }
        }
    }
    
    // MARK: - Sections
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 26) {
            HStack(alignment: .top) {
                // Logo and subtitle - proportionally sized (FORKI: 40, NUTRITION PET: 15)
                VStack(alignment: .leading, spacing: 4) {
                    Text("FORKI")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundColor(ForkiTheme.logo)
                        .shadow(color: ForkiTheme.logoShadow.opacity(0.35), radius: 6, x: 0, y: 4)
                    Text("NUTRITION PET")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(ForkiTheme.textSecondary)
                        .tracking(1.6)
                }
                Spacer()
                ForkiBatteryView(percentage: nutrition.avatarEnergyPercentage)
            }
            
            VStack(alignment: .center, spacing: 4) {
                Text("\(greeting), \(userData.name)!")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Text(nutrition.petMessage)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var avatarStage: some View {
        ZStack {
            // Avatar stage background - FORKI_Game dark blue
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(ForkiTheme.avatarStageBackground)
                .modifier(SparkleOverlayModifier())
                .overlay(
                    // Pixelated starfield effect
                    ZStack {
                        // Small white stars
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 3, height: 3)
                            .offset(x: -60, y: -80)
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 3, height: 3)
                            .offset(x: 80, y: -60)
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 2, height: 2)
                            .offset(x: -40, y: 100)
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 3, height: 3)
                            .offset(x: 100, y: 80)
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 2, height: 2)
                            .offset(x: -20, y: -40)
                        Circle()
                            .fill(Color.white.opacity(0.3))
                            .frame(width: 3, height: 3)
                            .offset(x: 60, y: 40)
                    }
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(Color(hex: "#7B68C4"), lineWidth: 4) // Purple border - border-4
                )
                .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 14)
            
            VStack(spacing: 0) {
                // Speech bubble at top (moved up)
                ForkiSpeechBubble(text: petMoodText)
                    .padding(.top, 20)
                    .padding(.bottom, 12)
                
                // Avatar view circle (moved up)
                ZStack {
                    Circle()
                        .fill(ForkiTheme.avatarRing.opacity(0.6))
                        .frame(width: 230, height: 230)
                        .shadow(color: Color.black.opacity(0.1), radius: 18, x: 0, y: 10)
                    
                    // Fixed frame container to prevent layout shifts
                    ZStack {
                        AvatarView(
                            state: nutrition.avatarState,
                            showFeedingEffect: $showFeedingEffect,
                            size: 200
                        )
                        .clipShape(Circle())
                        
                        // Celebration glow overlay (doesn't affect layout)
                        if celebrating {
                            Circle()
                                .fill(Color.purple.opacity(0.45))
                                .frame(width: 200, height: 200)
                                .blur(radius: 30)
                                .allowsHitTesting(false)
                        }
                    }
                    .frame(width: 200, height: 200) // Fixed frame prevents layout shifts
                    .scaleEffect(celebrating ? 1.06 : 1.0)
                    .animation(.spring(response: 0.55, dampingFraction: 0.65), value: celebrating)
                    .clipped() // Ensure scale doesn't overflow
                }
                .padding(.bottom, 16)
                
                // Meals logged text at bottom inside the Avatar Stage
                Text(mealsLoggedText)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 380) // Slightly increased to fit everything
    }
    
    private var primaryActions: some View {
        HStack(spacing: 18) {
            // Log Food button - Mint gradient
            ForkiActionButton(
                title: "Log Food",
                icon: "fork.knife",
                gradient: LinearGradient(
                    colors: [Color(hex: "#8DD4D1"), Color(hex: "#6FB8B5")], // Mint gradient
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                foreground: .white,
                border: Color(hex: "#7AB8B5"), // Border color for mint button
                dropShadow: ForkiTheme.actionShadow
            ) {
                aiPrefill = nil
                showFoodLogger = true
            }
            
            // Recipes button - Pink gradient
            ForkiActionButton(
                title: "Recipes",
                icon: "book.pages",
                gradient: LinearGradient(
                    colors: [Color(hex: "#F5C9E0"), Color(hex: "#E8B3D4")], // Pink gradient
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                foreground: Color(hex: "#9B7FBF"), // Purple text matching reference
                border: Color(hex: "#DDA5CC"), // Border color for pink button
                dropShadow: ForkiTheme.actionShadow
            ) {
                showRecipes = true
            }
        }
    }
    
    private var caloriesProgressCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Daily Calories")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "#9B7FBF")) // Light purple text
                    .tracking(2)
                Spacer()
                Text("\(nutrition.caloriesCurrent) / \(nutrition.caloriesGoal)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#9B7FBF")) // Light purple text
                    .monospacedDigit()
            }
            
            ForkiCaloriesBar(segments: nutrientSegments, progress: caloriesProgressValue)
                .frame(height: 40)
            
            HStack(spacing: 12) {
                ForEach(nutrientSegments) { segment in
                    ForkiLegendItem(segment: segment)
                }
            }
            
            Text(progressMessage)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(progressMessageColor)
                .tracking(1)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FFE4F0"), Color(hex: "#FFF0F5")], // Light pink gradient
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color(hex: "#E8B3D4"), lineWidth: 4) // Pink border
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
    }
    
    private var progressMessageColor: Color {
        switch caloriesProgressValue {
        case ..<0.6:
            return Color(hex: "#EF5350") // Red for "Keep going"
        case ..<1.1:
            return Color(hex: "#009E48") // Green for happy/strong (60-110%)
        default:
            return ForkiTheme.borderPrimary // Bolder purple for overfull/bloated (≥110%)
        }
    }
    
    private var bottomBar: some View {
        UniversalNavigationBar(
            onHome: {
                // Already on home - dismiss any overlays
                showExplore = false
                showStats = false
                showProfile = false
                showRecipes = false
            },
            onExplore: {
                showStats = false
                showProfile = false
                showRecipes = false
                showExplore = true
            },
            onCamera: {
                showAICamera = true
            },
            onProgress: {
                showExplore = false
                showProfile = false
                showRecipes = false
                showStats = true
            },
            onProfile: {
                showExplore = false
                showStats = false
                showRecipes = false
                showProfile = true
            },
            currentScreen: .home
        )
    }
    
    private var mealsLoggedText: String {
        let count = nutrition.mealsLoggedToday
        let mealWord = count == 1 ? "meal" : "meals"
        return "\(count) \(mealWord) logged today"
    }
    
    private var nutrientSegments: [ForkiNutrientSegment] {
        let proteinCalories = max(nutrition.proteinCurrent * 4, 0)
        let carbCalories = max(nutrition.carbsCurrent * 4, 0)
        let fatCalories = max(nutrition.fatsCurrent * 9, 0)
        
        return [
            ForkiNutrientSegment(
                name: "Protein",
                grams: nutrition.proteinCurrent,
                calories: proteinCalories,
                color: Color(hex: "#8DD4D1"),
                gradient: LinearGradient(
                    colors: [Color(hex: "#8DD4D1"), Color(hex: "#A0DDD9")], // Mint/teal gradient
                    startPoint: .leading,
                    endPoint: .trailing
                )
            ),
            ForkiNutrientSegment(
                name: "Carbs",
                grams: nutrition.carbsCurrent,
                calories: carbCalories,
                color: Color(hex: "#FFE8A3"),
                gradient: LinearGradient(
                    colors: [Color(hex: "#FFE8A3"), Color(hex: "#FFF2C8")], // Yellow gradient
                    startPoint: .leading,
                    endPoint: .trailing
                )
            ),
            ForkiNutrientSegment(
                name: "Fats",
                grams: nutrition.fatsCurrent,
                calories: fatCalories,
                color: Color(hex: "#9B7FBF"),
                gradient: LinearGradient(
                    colors: [Color(hex: "#9B7FBF"), Color(hex: "#B399D1")], // Lavender purple gradient
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        ]
    }
    
    private var totalNutrientCalories: Double {
        let total = nutrientSegments.reduce(0) { $0 + $1.calories }
        return max(total, 1)
    }
    
    private var caloriesProgressValue: Double {
        let goal = max(Double(nutrition.caloriesGoal), 1)
        return Double(nutrition.caloriesCurrent) / goal // Allow values > 1.0 for overfull state
    }
    
    private var progressMessage: String {
        switch caloriesProgressValue {
        case ..<0.25:
            return "Let's get Forki fed!"
        case ..<0.6:
            return "Nice bites! Keep going!"
        case ..<0.9:
            return "Great progress! Almost there!"
        case ..<1.1:
            return "Amazing! You're on target!"
        default:
            return "Whoa! Forki is super full!"
        }
    }
    
}

// MARK: - Theme & Helper Models

private struct ForkiNutrientSegment: Identifiable {
    let name: String
    let grams: Double
    let calories: Double
    let color: Color
    let gradient: LinearGradient?
    
    init(name: String, grams: Double, calories: Double, color: Color, gradient: LinearGradient? = nil) {
        self.name = name
        self.grams = grams
        self.calories = calories
        self.color = color
        self.gradient = gradient
    }
    
    var id: String { name }
    
    var labelText: String {
        "\(name.uppercased()) \(Int(round(grams)))g"
    }
}

// MARK: - Decorative Backgrounds

private struct ForkiCheckerboard: View {
    let colorA: Color
    let colorB: Color
    let squareSize: CGFloat
    
    var body: some View {
        Canvas { context, size in
            guard squareSize > 0 else { return }
            let columns = Int(ceil(size.width / squareSize))
            let rows = Int(ceil(size.height / squareSize))
            
            for row in 0...rows {
                for column in 0...columns {
                    let origin = CGPoint(
                        x: CGFloat(column) * squareSize,
                        y: CGFloat(row) * squareSize
                    )
                    let rect = CGRect(origin: origin, size: CGSize(width: squareSize, height: squareSize))
                    let path = Path(rect)
                    let useColorA = (row + column).isMultiple(of: 2)
                    context.fill(path, with: .color(useColorA ? colorA : colorB))
                }
            }
        }
    }
}

// MARK: - Buttons & UI Elements

private struct ForkiActionButton: View {
    let title: String
    let icon: String
    let gradient: LinearGradient?
    let background: Color?
    let foreground: Color
    let border: Color
    let dropShadow: Color
    let action: () -> Void
    
    init(
        title: String,
        icon: String,
        gradient: LinearGradient? = nil,
        background: Color? = nil,
        foreground: Color,
        border: Color,
        dropShadow: Color,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.gradient = gradient
        self.background = background
        self.foreground = foreground
        self.border = border
        self.dropShadow = dropShadow
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text(title.uppercased())
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        gradient != nil 
                            ? AnyShapeStyle(gradient!)
                            : AnyShapeStyle(background ?? ForkiTheme.actionLogFood)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(border, lineWidth: 4) // FORKI_Game style - border-4
                    )
            )
            .foregroundColor(foreground)
            .shadow(color: dropShadow, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

private struct ForkiLegendItem: View {
    let segment: ForkiNutrientSegment
    
    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(segment.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(
                            segment.name == "Protein" ? Color(hex: "#7AB8B5") :
                            segment.name == "Carbs" ? Color(hex: "#FFD98F") :
                            segment.name == "Fats" ? Color(hex: "#8568A8") :
                            Color(hex: "#E8B3D4"), // Pink border for Fiber
                            lineWidth: 2
                        )
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(segment.name.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#9B7FBF")) // Light purple
                    .tracking(1.5)
                Text("\(Int(round(segment.grams)))g")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#2C2C2C")) // Dark text
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}

//
//  ForkiBatteryView.swift — 5-Segment Edition with Neon Pulse Glow
//

private struct ForkiBatteryView: View {
    let percentage: Int
    var avatarStateColorOverride: Color? = nil

    @State private var pulseGlow = false

    private var batteryColor: Color {
        if let override = avatarStateColorOverride { return override }
        if percentage > 100 { return ForkiTheme.batteryFillOver }      // Purple (overfull)
        if percentage > 60  { return ForkiTheme.batteryFillHigh }      // Mint
        if percentage > 30  { return ForkiTheme.batteryFillMedium }    // Yellow
        return ForkiTheme.batteryFillLow                               // Red
    }

    // Determines how many of the 5 segments are filled
    private var filledSegments: Int {
        let ratio = min(max(Double(percentage) / 100.0, 0), 1.0)
        return Int(ratio * 5.0 + 0.001)  // avoid rounding errors
    }

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 12) {

                ZStack {

                    // 🔮 Purple Glow (only if >110%)
                    if percentage > 110 {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.purple.opacity(0.55))
                            .blur(radius: pulseGlow ? 14 : 4)
                            .scaleEffect(pulseGlow ? 1.12 : 0.96)
                            .animation(
                                Animation.easeInOut(duration: 1.3).repeatForever(),
                                value: pulseGlow
                            )
                            .onAppear { pulseGlow = true }
                            .onDisappear { pulseGlow = false }
                            .frame(width: 86, height: 44)
                    }

                    // 🔋 Battery Container
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ForkiTheme.batteryTrack)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
                        )
                        .frame(width: 72, height: 34)

                    // 🔌 Battery Tip
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ForkiTheme.borderPrimary)
                        .frame(width: 4, height: 12)
                        .offset(x: 38)

                    // 🟦 5 Segments
                    HStack(spacing: 4) {
                        ForEach(0..<5) { index in
                            RoundedRectangle(cornerRadius: 4)
                                .fill(
                                    index < filledSegments
                                    ? batteryColor
                                    : ForkiTheme.batteryTrack.opacity(0.35)
                                )
                                .frame(width: 10, height: 20)
                                .animation(
                                    .spring(response: 0.45, dampingFraction: 0.8),
                                    value: filledSegments
                                )
                        }
                    }
                }
                .frame(width: 78, height: 38)

                // 🔢 Battery Text
                Text(percentage > 100 ? "Full+" : "\(percentage)%")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(
                        percentage > 30 ? ForkiTheme.textPrimary : ForkiTheme.batteryFillLow
                    )
                    .monospacedDigit()
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text("LIFE ENERGY")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
                .tracking(2)
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [
                    Color(hex: "#1E2742").opacity(0.85),
                    Color(hex: "#2A3441").opacity(0.80)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "#7B68C4"), lineWidth: 4) // glowing border
        )
        .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 8)
    }
}

private struct ForkiCaloriesBar: View {
    let segments: [ForkiNutrientSegment]
    let progress: Double
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let clampedProgress = min(max(progress, 0), 1)
            let progressWidth = CGFloat(clampedProgress) * totalWidth
            let totalCalories = max(segments.reduce(0) { $0 + $1.calories }, 1)
            let widths = segments.map { CGFloat($0.calories / totalCalories) * progressWidth }
            let cumulative = widths.reduce(into: [CGFloat]()) { result, width in
                result.append((result.last ?? 0) + width)
            }
            
            ZStack(alignment: .leading) {
                // Background track with rounded corners
                Capsule(style: .continuous)
                    .fill(Color(hex: "#FFD4E5")) // Light pink background
                    .overlay(
                        Capsule(style: .continuous)
                            .stroke(Color(hex: "#F5C9E0"), lineWidth: 2) // Lighter pink border
                    )
                
                // Fill segments - rectangular, no rounded corners, no gaps
                ForEach(Array(zip(segments.indices, segments)), id: \.1.id) { index, segment in
                    let width = max(widths[index], 0)
                    let start = index == 0 ? 0 : cumulative[index - 1]
                    
                    // Use Rectangle instead of Capsule for seamless connection
                    Rectangle()
                        .fill(
                            segment.gradient != nil
                                ? AnyShapeStyle(segment.gradient!)
                                : AnyShapeStyle(segment.color)
                        )
                        .frame(width: width, height: totalHeight)
                        .offset(x: start)
                }
                
                // Percentage indicator on the white/empty side
                HStack(alignment: .center) {
                    Text("\(Int(round(clampedProgress * 100)))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "#9B7FBF")) // Light purple
                        .monospacedDigit()
                }
                .frame(width: totalWidth - progressWidth)
                .offset(x: progressWidth)
            }
        }
    }
}

private struct ForkiExploreScreen: View {
    let userData: UserData
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ZStack {
                ForkiTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    onDismiss()
                                }
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(ForkiTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Text("Explore")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                            
                            Spacer()
                            
                            Color.clear
                                .frame(width: 24, height: 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // Explore Content
                        VStack(spacing: 20) {
                            Text("Explore is coming soon!")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                            Text("We're cooking up nearby restaurants and menus for Forki. Stay tuned!")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(ForkiTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(ForkiTheme.panelBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
                        )
                        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
                        .padding(.horizontal, 16)
                        
                        Spacer().frame(height: 100) // room for bottom bar
                    }
                    .padding(.bottom, 20)
                }
            }
            
            // Bottom Navigation Bar
            UniversalNavigationBar(
                onHome: {
                    onDismiss()
                },
                onExplore: { /* Already on explore */ },
                onCamera: { /* Camera handled elsewhere */ },
                onProgress: { /* Progress handled elsewhere */ },
                onProfile: { /* Profile handled elsewhere */ },
                currentScreen: .explore
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }
}

private struct ForkiProfileScreen: View {
    let userData: UserData
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ZStack {
                ForkiTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HStack {
                            Button {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    onDismiss()
                                }
                            } label: {
                                Image(systemName: "arrow.left")
                                    .font(.title2)
                                    .foregroundColor(ForkiTheme.textPrimary)
                            }
                            
                            Spacer()
                            
                            Text("Profile")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                            
                            Spacer()
                            
                            Color.clear
                                .frame(width: 24, height: 24)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        
                        // Profile Content
                        VStack(spacing: 20) {
                            Text("Profile is in progress")
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                            
                            Text("Soon you'll personalize Forki with goals, preferences, and more.")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundColor(ForkiTheme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                        }
                        .padding(30)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(ForkiTheme.panelBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
                        )
                        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
                        .padding(.horizontal, 16)
                        
                        Spacer().frame(height: 100) // room for bottom bar
                    }
                    .padding(.bottom, 20)
                }
            }
            
            // Bottom Navigation Bar
            UniversalNavigationBar(
                onHome: {
                    onDismiss()
                },
                onExplore: { /* Explore handled elsewhere */ },
                onCamera: { /* Camera handled elsewhere */ },
                onProgress: { /* Progress handled elsewhere */ },
                onProfile: { /* Already on profile */ },
                currentScreen: .profile
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 16)
        }
    }
}

private struct ForkiSpeechBubble: View {
    let text: String
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                Text(text.uppercased())
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(Color(hex: "#4A148C")) // Dark purple text
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white) // White background
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(ForkiTheme.logo, lineWidth: 2) // Teal border matching FORKI logo
                            )
                    )
                
                // Triangle tail with rounded top corners - border only on bottom two edges
                RoundedTriangleTail()
                    .fill(Color.white) // White fill
                    .overlay(
                        TriangleBottomEdgesOnly()
                            .stroke(ForkiTheme.logo, lineWidth: 2) // Teal border only on bottom two edges
                    )
                    .frame(width: 20, height: 14) // Slightly taller to ensure overlap
                    .offset(x: 16, y: -4) // More overlap to fill any gaps
            }
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 3)
        }
    }
}

private struct RoundedTriangleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 3 // Rounded corners at top
        let overlap: CGFloat = 2 // Extend top to ensure overlap with bubble
        let midX = rect.midX
        
        // Create left half of triangle (from left edge to center)
        var leftHalf = Path()
        // Start from left edge (after rounded corner)
        leftHalf.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        // Left edge down to point (bottom center)
        leftHalf.addLine(to: CGPoint(x: midX, y: rect.maxY))
        // Top edge from center to left (with overlap)
        leftHalf.addLine(to: CGPoint(x: midX, y: rect.minY - overlap))
        // Curve along top-left rounded corner back to start
        leftHalf.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.minX + cornerRadius/2, y: rect.minY - overlap/2)
        )
        leftHalf.closeSubpath()
        
        // Add left half to main path
        path.addPath(leftHalf)
        
        // Create right half by mirroring left half horizontally
        var rightHalf = leftHalf
        rightHalf = rightHalf.applying(CGAffineTransform(translationX: -midX, y: 0))
        rightHalf = rightHalf.applying(CGAffineTransform(scaleX: -1, y: 1))
        rightHalf = rightHalf.applying(CGAffineTransform(translationX: midX, y: 0))
        
        // Add right half to main path
        path.addPath(rightHalf)
        
        return path
    }
}

private struct TriangleBottomEdgesOnly: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerRadius: CGFloat = 3 // Match the rounded corners
        let midX = rect.midX
        
        // Create left edge path
        var leftEdge = Path()
        leftEdge.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        leftEdge.addLine(to: CGPoint(x: midX, y: rect.maxY))
        
        // Add left edge to main path
        path.addPath(leftEdge)
        
        // Create right edge by mirroring left edge horizontally
        var rightEdge = leftEdge
        rightEdge = rightEdge.applying(CGAffineTransform(translationX: -midX, y: 0))
        rightEdge = rightEdge.applying(CGAffineTransform(scaleX: -1, y: 1))
        rightEdge = rightEdge.applying(CGAffineTransform(translationX: midX, y: 0))
        
        // Add right edge to main path
        path.addPath(rightEdge)
        
        // Don't close the path - this leaves the top edge open for seamless connection
        return path
    }
}

// MARK: - Preview

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        let userData: UserData = {
            let data = UserData()
            data.name = "Janice"
            data.email = "test@example.com"
            return data
        }()
        
        return HomeScreen(loggedFoods: [])
            .environmentObject(userData)
            .environmentObject(NutritionState(goal: 2000))
    }
}
