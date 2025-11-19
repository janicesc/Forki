//
//  ProgressScreen.swift
//  Forki
//
//  Created by Janice C on 9/16/25.
//  Refactored for habit-focused progress tracking
//

import SwiftUI

struct ProgressScreen: View {
    let userData: UserData
    @ObservedObject var nutrition: NutritionState
    var onDismiss: (() -> Void)? = nil
    var onHome: (() -> Void)? = nil
    var onExplore: (() -> Void)? = nil
    var onCamera: (() -> Void)? = nil
    var onProfile: (() -> Void)? = nil
    
    init(userData: UserData, nutrition: NutritionState, onDismiss: (() -> Void)? = nil, onHome: (() -> Void)? = nil, onExplore: (() -> Void)? = nil, onCamera: (() -> Void)? = nil, onProfile: (() -> Void)? = nil) {
        self.userData = userData
        self.nutrition = nutrition
        self.onDismiss = onDismiss
        self.onHome = onHome
        self.onExplore = onExplore
        self.onCamera = onCamera
        self.onProfile = onProfile
    }
    
    // Navigation state
    @State private var showRecipes = false
    @State private var showAICamera = false
    @State private var showProfile = false
    
    // Use ForkiTheme background gradient
    private static let bgGradient = ForkiTheme.backgroundGradient
    
    // Derived properties
    private var avatarState: AvatarState { nutrition.avatarState }
    private var mealsLoggedToday: Int { 
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return nutrition.loggedMeals.filter { 
            calendar.startOfDay(for: $0.timestamp) == today 
        }.count
    }
    private var loggedFoods: [LoggedFood] { nutrition.loggedMeals }
    
    // Get persona info from UserDefaults (set during onboarding)
    private var personaID: Int {
        UserDefaults.standard.integer(forKey: "hp_personaID")
    }
    
    // Get persona profile (simplified - would ideally come from WellnessSnapshot)
    private var personaProfile: PersonaProfile? {
        // This is a simplified version - in production, you'd load from WellnessSnapshot
        // For now, we'll use the personaID from NutritionState or UserDefaults
        let pid = nutrition.personaID > 0 ? nutrition.personaID : personaID
        return getPersonaProfile(for: pid)
    }
    
    var body: some View {
        ZStack {
            Self.bgGradient.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Main content
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        headerSection
                        
                        // 1. Forki Avatar + Emotional Encouragement Card (with Consistency Score)
                        forkiAvatarCard
                        
                        // 2. Weekly Habit Score
                        weeklyHabitScoreCard
                        
                        // 4. Eating Pattern Insights (Persona-Based)
                        eatingPatternInsightsCard
                        
                        // 5. Goal Progress Summary (goal-dependent)
                        goalProgressSummaryCard
                        
                        // 6. Pet Challenge Tracker
                        petChallengeTrackerCard
                        
                        Spacer().frame(height: 100) // room for bottom bar
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
                
                Spacer(minLength: 0)
                
                // Bottom Navigation Bar - docked to bottom safe area
                universalNavigationBar
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
        .overlay {
            if showRecipes {
                RecipesView(
                    currentScreen: .constant(6),
                    loggedFoods: .constant(loggedFoods),
                    onFoodLogged: { _ in },
                    userData: userData
                )
                .transition(.smoothTransition)
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showAICamera) {
            Text("AI Camera functionality coming soon")
        }
        .sheet(isPresented: $showProfile) {
            Text("Profile functionality coming soon")
        }
        .onAppear {
            // DEBUG: Print personaID for validation
            print("DEBUG PERSONA:", userData.personaID)
        }
    }
    
    // MARK: - Navigation Bar
    private var universalNavigationBar: some View {
        UniversalNavigationBar(
            onHome: {
                if let onHome = onHome {
                    onHome()
                } else if let onDismiss = onDismiss {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        onDismiss()
                    }
                }
            },
            onExplore: {
                if let onExplore = onExplore {
                    onExplore()
                } else {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        showRecipes = true
                    }
                }
            },
            onCamera: {
                if let onCamera = onCamera {
                    onCamera()
                } else {
                    showAICamera = true
                }
            },
            onProgress: { /* Already on progress screen */ },
            onProfile: {
                if let onProfile = onProfile {
                    onProfile()
                } else {
                    showProfile = true
                }
            },
            currentScreen: .progress
        )
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                if onDismiss != nil {
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            onDismiss?()
                        }
                    } label: {
                        Image(systemName: "arrow.left")
                            .font(.title2)
                            .foregroundColor(ForkiTheme.textPrimary)
                    }
                } else {
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                
                Spacer()
                
                Text("My Progress")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                
                Spacer()
                
                Color.clear
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - 1. Forki Avatar + Emotional Encouragement Card (A1 + B2 Layout)
    private var forkiAvatarCard: some View {
        VStack(spacing: 1) {
            // Top row: Large Avatar (left) + Consistency Score Ring (right) - Level and parallel
            HStack(alignment: .top, spacing: 20) {
                // Left half: Large Avatar - balanced spacing
                VStack(spacing: 0) {
                    // Title centered above avatar view
                    Text("Your Forki Today")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 3) // Add 3px spacing below title
                    
                    // Spacer to position Avatar closer to title
                    Spacer()
                        .frame(height: 7) // Reduced spacing to move avatar up
                    
                    AvatarView(state: avatarState, showFeedingEffect: .constant(false), size: 142) // 10% smaller (158 * 0.9 = 142.2 ≈ 142)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: ForkiTheme.borderPrimary.opacity(0.15), radius: 10, x: 0, y: 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 5) // Left spacing
                
                // Right half: Consistency Score Ring with centered title above
                VStack(spacing: 0) {
                    // Spacer to move Consistency Score and ring down by 5px
                    Spacer()
                        .frame(height: 5)
                    
                    // Title centered above the ring
                    Text("Consistency Score")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 15) // 15px padding below title to separate from ring
                    
                    // Consistency Score Ring
                    ZStack {
                        Circle()
                            .stroke(ForkiTheme.progressTrack, lineWidth: 10)
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .trim(from: 0, to: todayConsistencyScore / 100)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(colors: [ForkiTheme.highlightText, ForkiTheme.borderPrimary]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 10, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 120, height: 120)
                        
                        Text("\(Int(todayConsistencyScore))%")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundColor(ForkiTheme.textPrimary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 5) // Right spacing - matches left spacing
            }
            .padding(.bottom, 14) // Spacing below avatar and ring (increased by 2px)
            
            // Bottom center: Emotional / Action Lines
            VStack(spacing: 6) {
                // Emotional Line
                Text(emotionalLine)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                    .multilineTextAlignment(.center)
                    .padding(.top, 2) // 2px padding above status text
                
                // Action Line
                Text(actionLine)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
                    .multilineTextAlignment(.center)
                
                // Daily streak (if any)
                if dailyStreak > 0 {
                    HStack(spacing: 4) {
                        Text("🔥")
                            .font(.system(size: 12))
                        Text("\(dailyStreak) day streak")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundColor(ForkiTheme.highlightText)
                    }
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ForkiTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
    }
    
    // MARK: - 2. Weekly Habit Score
    private var weeklyHabitScoreCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("📊")
                    .font(.system(size: 16))
                Text("Weekly Habit Score")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                Spacer()
            }
            
            // Horizontal streak bar
            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    ForEach(0..<7) { dayIndex in
                        let dayData = weeklyHabitData[dayIndex]
                        RoundedRectangle(cornerRadius: 4)
                            .fill(dayData.isGood ? ForkiTheme.highlightText : ForkiTheme.progressTrack)
                            .frame(height: 32)
                            .overlay(
                                Text(dayData.dayLabel)
                                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                                    .foregroundColor(dayData.isGood ? ForkiTheme.textPrimary : ForkiTheme.textSecondary)
                            )
                    }
                }
                
                // Insights
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(weeklyInsights, id: \.self) { insight in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(ForkiTheme.highlightText)
                                .frame(width: 6, height: 6)
                            Text(insight)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundColor(ForkiTheme.textSecondary)
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ForkiTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
    }
    
    // MARK: - 4. Eating Pattern Insights (Persona-Based)
    private var eatingPatternInsightsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🥗")
                    .font(.system(size: 16))
                Text("Your Eating Rhythm")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                Spacer()
            }
            
            // Simple meal timing heatmap (24h × 7 grid simplified)
            VStack(spacing: 12) {
                // Most consistent/skipped meals
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Most Consistent")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(ForkiTheme.textSecondary)
                        Text(mostConsistentMeal)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(ForkiTheme.highlightText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Most Skipped")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(ForkiTheme.textSecondary)
                        Text(mostSkippedMeal)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(ForkiTheme.batteryFillLow)
                    }
                }
                
                // Persona-based insight
                Text(personaBasedInsight)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                    .padding(12)
                    .background(ForkiTheme.surface.opacity(0.6))
                    .cornerRadius(12)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ForkiTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
    }
    
    // MARK: - 5. Goal Progress Summary (goal-dependent)
    private var goalProgressSummaryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🎯")
                    .font(.system(size: 16))
                Text("Goal Progress")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                ForEach(goalProgressItems, id: \.self) { item in
                    HStack(spacing: 12) {
                        Circle()
                            .fill(ForkiTheme.highlightText)
                            .frame(width: 8, height: 8)
                        Text(item)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(ForkiTheme.textPrimary)
                    }
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ForkiTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
    }
    
    // MARK: - 6. Pet Challenge Tracker
    private var petChallengeTrackerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("🏆")
                    .font(.system(size: 16))
                Text("Week 1 Pet Challenge")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                Spacer()
            }
            
            if let persona = personaProfile {
                VStack(alignment: .leading, spacing: 12) {
                    Text(persona.petChallenge)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                    
                    // Progress bar
                    HStack(spacing: 12) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ForkiTheme.progressTrack)
                                    .frame(height: 16)
                                
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ForkiTheme.highlightText)
                                    .frame(width: geometry.size.width * challengeProgress, height: 16)
                            }
                        }
                        .frame(height: 16)
                        
                        Text("\(challengeDaysCompleted)/\(challengeTotalDays)")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(ForkiTheme.textPrimary)
                            .frame(width: 50)
                    }
                }
            } else {
                Text("Complete onboarding to unlock your pet challenge!")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textSecondary)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(ForkiTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
    }
    
    // MARK: - Computed Properties
    
    // Emotional Line (state-based)
    private var emotionalLine: String {
        switch avatarState {
        case .starving: return "Forki is really hungry."
        case .sad: return "Forki is feeling low."
        case .neutral: return "Forki is doing okay today."
        case .happy: return "Forki is feeling good today!"
        case .strong: return "Forki is energized!"
        case .overfull: return "Forki is feeling too full."
        case .bloated: return "Forki feels a bit uncomfortable."
        case .dead: return "Forki needs your help."
        }
    }
    
    // Action Line (state-based)
    private var actionLine: String {
        switch avatarState {
        case .starving, .sad, .dead:
            return "Let's fuel Forki today."
        case .neutral:
            return "A meal check-in keeps Forki thriving."
        case .happy:
            return "Nice work — let's keep the streak alive!"
        case .strong:
            return "Great momentum — stay consistent!"
        case .overfull, .bloated:
            return "Let's balance Forki's meals today."
        }
    }
    
    private var dailyStreak: Int {
        let calendar = Calendar.current
        var streak = 0
        var currentDate = calendar.startOfDay(for: Date())
        
        while streak < 30 { // Max 30 day streak check
            let mealsOnDay = nutrition.loggedMeals.filter {
                calendar.startOfDay(for: $0.timestamp) == currentDate
            }
            
            if mealsOnDay.count >= 2 {
                streak += 1
                if let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
                    currentDate = calendar.startOfDay(for: previousDay)
                } else {
                    break
                }
            } else {
                break
            }
        }
        
        return streak
    }
    
    // Today's Consistency Score (weighted)
    private var todayConsistencyScore: Double {
        var score: Double = 0
        
        // 40% - Logged at least 2 meals
        if mealsLoggedToday >= 2 {
            score += 40
        } else if mealsLoggedToday == 1 {
            score += 20
        }
        
        // 30% - Logged breakfast/lunch/dinner
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let hour = calendar.component(.hour, from: Date())
        
        var mealTypesLogged = 0
        let breakfastEnd = calendar.date(byAdding: .hour, value: 10, to: today) ?? today
        let lunchStart = calendar.date(byAdding: .hour, value: 11, to: today) ?? today
        let lunchEnd = calendar.date(byAdding: .hour, value: 14, to: today) ?? today
        let dinnerStart = calendar.date(byAdding: .hour, value: 17, to: today) ?? today
        
        let todayMeals = nutrition.loggedMeals.filter {
            calendar.startOfDay(for: $0.timestamp) == today
        }
        
        for meal in todayMeals {
            let mealHour = calendar.component(.hour, from: meal.timestamp)
            if mealHour < 10 {
                mealTypesLogged |= 1 // Breakfast
            } else if mealHour >= 11 && mealHour < 14 {
                mealTypesLogged |= 2 // Lunch
            } else if mealHour >= 17 {
                mealTypesLogged |= 4 // Dinner
            }
        }
        
        let mealCount = (mealTypesLogged & 1 != 0 ? 1 : 0) + (mealTypesLogged & 2 != 0 ? 1 : 0) + (mealTypesLogged & 4 != 0 ? 1 : 0)
        score += Double(mealCount) / 3.0 * 30
        
        // 15% - Hit calorie target ±10%
        let calorieRatio = Double(nutrition.caloriesCurrent) / Double(max(1, nutrition.caloriesGoal))
        if calorieRatio >= 0.9 && calorieRatio <= 1.1 {
            score += 15
        } else if calorieRatio >= 0.8 && calorieRatio <= 1.2 {
            score += 7.5
        }
        
        // 15% - Hit protein target ≥80%
        let proteinGoal = Double(nutrition.caloriesGoal) * 0.25 / 4.0 // Rough estimate: 25% of calories from protein
        let proteinRatio = nutrition.proteinCurrent / max(1, proteinGoal)
        if proteinRatio >= 0.8 {
            score += 15
        } else if proteinRatio >= 0.6 {
            score += 7.5
        }
        
        return min(score, 100)
    }
    
    
    // Weekly habit data
    private var weeklyHabitData: [(dayLabel: String, isGood: Bool)] {
        let calendar = Calendar.current
        let now = Date()
        var data: [(String, Bool)] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else {
                data.append(("", false))
                continue
            }
            
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            let dayName = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
            let isGood = mealsOnDay.count >= 2
            
            data.append((dayName, isGood))
        }
        
        return data.reversed() // Most recent day last
    }
    
    private var weeklyInsights: [String] {
        var insights: [String] = []
        let goodDays = weeklyHabitData.filter { $0.isGood }
        let goodDayNames = weeklyHabitData.enumerated().filter { $0.element.isGood }
            .map { weeklyHabitData[$0.offset].dayLabel }
        
        if !goodDayNames.isEmpty {
            let dayList = goodDayNames.joined(separator: ", ")
            insights.append("You were most consistent on \(dayList).")
        }
        
        let underFueledDays = 7 - goodDays.count
        if underFueledDays > 0 {
            insights.append("\(underFueledDays) day\(underFueledDays == 1 ? "" : "s") under-fueled.")
        }
        
        // Check late-night eating for personas 3, 10, 5
        let personaID = nutrition.personaID > 0 ? nutrition.personaID : personaID
        if [3, 10, 5].contains(personaID) {
            let lateNightCount = countLateNightMeals()
            if lateNightCount < 3 {
                insights.append("Late-night eating improved.")
            }
        }
        
        return insights.isEmpty ? ["Keep logging meals to see insights!"] : insights
    }
    
    private func countLateNightMeals() -> Int {
        let calendar = Calendar.current
        let now = Date()
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let lateNightStart = calendar.date(byAdding: .hour, value: 21, to: startOfDay) ?? startOfDay
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let lateMeals = nutrition.loggedMeals.filter {
                $0.timestamp >= lateNightStart && $0.timestamp < endOfDay
            }
            
            if !lateMeals.isEmpty {
                count += 1
            }
        }
        
        return count
    }
    
    private var mostConsistentMeal: String {
        let calendar = Calendar.current
        var breakfastCount = 0
        var lunchCount = 0
        var dinnerCount = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            for meal in mealsOnDay {
                let hour = calendar.component(.hour, from: meal.timestamp)
                if hour < 10 {
                    breakfastCount += 1
                } else if hour >= 11 && hour < 14 {
                    lunchCount += 1
                } else if hour >= 17 {
                    dinnerCount += 1
                }
            }
        }
        
        if dinnerCount >= lunchCount && dinnerCount >= breakfastCount {
            return "Dinner"
        } else if lunchCount >= breakfastCount {
            return "Lunch"
        } else {
            return "Breakfast"
        }
    }
    
    private var mostSkippedMeal: String {
        let calendar = Calendar.current
        var breakfastCount = 0
        var lunchCount = 0
        var dinnerCount = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            var hasBreakfast = false
            var hasLunch = false
            var hasDinner = false
            
            for meal in mealsOnDay {
                let hour = calendar.component(.hour, from: meal.timestamp)
                if hour < 10 {
                    hasBreakfast = true
                } else if hour >= 11 && hour < 14 {
                    hasLunch = true
                } else if hour >= 17 {
                    hasDinner = true
                }
            }
            
            if !hasBreakfast { breakfastCount += 1 }
            if !hasLunch { lunchCount += 1 }
            if !hasDinner { dinnerCount += 1 }
        }
        
        if breakfastCount >= lunchCount && breakfastCount >= dinnerCount {
            return "Breakfast"
        } else if lunchCount >= dinnerCount {
            return "Lunch"
        } else {
            return "Dinner"
        }
    }
    
    private var personaBasedInsight: String {
        let personaID = nutrition.personaID > 0 ? nutrition.personaID : personaID
        let skippedBreakfast = mostSkippedMeal == "Breakfast"
        
        switch personaID {
        case 3: // Breakfast Skipper
            if skippedBreakfast {
                let skippedDays = countSkippedMealDays(mealType: "Breakfast")
                return "You skipped mornings \(skippedDays) days. Let's aim for 3 days with morning fuel next week."
            }
            return "Great job with morning meals! Keep it up."
        case 5, 10: // Stress Snacker / Overeater
            let lateNightCount = countLateNightMeals()
            if lateNightCount >= 4 {
                return "Try planning earlier dinners to reduce late-night eating."
            }
            return "Your meal timing is improving!"
        default:
            return "Keep building consistent eating habits. You're doing great!"
        }
    }
    
    private func countSkippedMealDays(mealType: String) -> Int {
        let calendar = Calendar.current
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            var hasMeal = false
            for meal in mealsOnDay {
                let hour = calendar.component(.hour, from: meal.timestamp)
                if mealType == "Breakfast" && hour < 10 {
                    hasMeal = true
                } else if mealType == "Lunch" && hour >= 11 && hour < 14 {
                    hasMeal = true
                } else if mealType == "Dinner" && hour >= 17 {
                    hasMeal = true
                }
            }
            
            if !hasMeal {
                count += 1
            }
        }
        
        return count
    }
    
    private var goalProgressItems: [String] {
        let goal = userData.normalizedGoal
        
        switch goal {
        case "Build healthier eating habits":
            let fullRhythmDays = countFullMealRhythmDays()
            let streak = dailyStreak
            let underEatingDays = 7 - weeklyHabitData.filter { $0.isGood }.count
            
            return [
                "\(fullRhythmDays) days with full meal rhythm",
                "\(streak) day streak",
                "\(underEatingDays) under-eating days"
            ]
            
        case "Lose weight":
            let deficitDays = countDeficitDays()
            let highCalDays = countHighCalorieDays()
            
            return [
                "\(deficitDays) days in calorie deficit",
                "\(highCalDays) high-calorie days this week",
                "Focus on portion control"
            ]
            
        case "Maintain my weight":
            let stabilityScore = calculateStabilityScore()
            
            return [
                "Stability score: \(Int(stabilityScore))%",
                "Calorie variance: ±\(Int(calculateCalorieVariance()))%",
                "Keep steady habits"
            ]
            
        case "Gain weight / build muscle":
            let surplusDays = countSurplusDays()
            let highProteinDays = countHighProteinDays()
            let missedMeals = countMissedMeals()
            
            return [
                "\(surplusDays) surplus days",
                "\(highProteinDays) high-protein days",
                "\(missedMeals) missed meals this week"
            ]
            
        case "Boost energy & reduce stress":
            let morningFuelDays = countMorningFuelDays()
            let lateNightReduction = 7 - countLateNightMeals()
            let spacingScore = calculateMealSpacingScore()
            
            return [
                "\(morningFuelDays) days with morning fuel",
                "Late-night eating reduced by \(lateNightReduction) days",
                "Meal spacing: \(Int(spacingScore))% consistent"
            ]
            
        default:
            return [
                "Track your progress",
                "Build healthy habits",
                "Stay consistent"
            ]
        }
    }
    
    private func countFullMealRhythmDays() -> Int {
        let calendar = Calendar.current
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            var hasBreakfast = false
            var hasLunch = false
            var hasDinner = false
            
            for meal in mealsOnDay {
                let hour = calendar.component(.hour, from: meal.timestamp)
                if hour < 10 {
                    hasBreakfast = true
                } else if hour >= 11 && hour < 14 {
                    hasLunch = true
                } else if hour >= 17 {
                    hasDinner = true
                }
            }
            
            if hasBreakfast && hasLunch && hasDinner {
                count += 1
            }
        }
        
        return count
    }
    
    private func countDeficitDays() -> Int {
        let calendar = Calendar.current
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            let dayCalories = mealsOnDay.reduce(0) { $0 + Int(Double($1.food.calories) * $1.portion) }
            if dayCalories < nutrition.caloriesGoal {
                count += 1
            }
        }
        
        return count
    }
    
    private func countHighCalorieDays() -> Int {
        let calendar = Calendar.current
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            let dayCalories = mealsOnDay.reduce(0) { $0 + Int(Double($1.food.calories) * $1.portion) }
            if dayCalories > Int(Double(nutrition.caloriesGoal) * 1.2) {
                count += 1
            }
        }
        
        return count
    }
    
    private func calculateStabilityScore() -> Double {
        let calendar = Calendar.current
        var dailyCalories: [Int] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            let dayCalories = mealsOnDay.reduce(0) { $0 + Int(Double($1.food.calories) * $1.portion) }
            dailyCalories.append(dayCalories)
        }
        
        guard !dailyCalories.isEmpty else { return 0 }
        let avg = Double(dailyCalories.reduce(0, +)) / Double(dailyCalories.count)
        var variance = 0.0
        
        for cal in dailyCalories {
            variance += pow(Double(cal) - avg, 2)
        }
        
        variance = variance / Double(dailyCalories.count)
        let stdDev = sqrt(variance)
        let coefficient = stdDev / max(1, avg)
        
        return max(0, 100 - (coefficient * 100))
    }
    
    private func calculateCalorieVariance() -> Double {
        let calendar = Calendar.current
        var dailyCalories: [Int] = []
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            let dayCalories = mealsOnDay.reduce(0) { $0 + Int(Double($1.food.calories) * $1.portion) }
            dailyCalories.append(dayCalories)
        }
        
        guard !dailyCalories.isEmpty else { return 0 }
        let avg = Double(dailyCalories.reduce(0, +)) / Double(dailyCalories.count)
        var maxDev = 0.0
        
        for cal in dailyCalories {
            let dev = abs(Double(cal) - avg) / max(1, avg) * 100
            maxDev = max(maxDev, dev)
        }
        
        return maxDev
    }
    
    private func countSurplusDays() -> Int {
        let calendar = Calendar.current
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            let dayCalories = mealsOnDay.reduce(0) { $0 + Int(Double($1.food.calories) * $1.portion) }
            if dayCalories > nutrition.caloriesGoal {
                count += 1
            }
        }
        
        return count
    }
    
    private func countHighProteinDays() -> Int {
        let calendar = Calendar.current
        var count = 0
        let proteinGoal = Double(nutrition.caloriesGoal) * 0.25 / 4.0 // Rough estimate
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            let dayProtein = mealsOnDay.reduce(0.0) { $0 + ($1.food.protein * $1.portion) }
            if dayProtein >= proteinGoal {
                count += 1
            }
        }
        
        return count
    }
    
    private func countMissedMeals() -> Int {
        let calendar = Calendar.current
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            if mealsOnDay.count < 2 {
                count += (2 - mealsOnDay.count)
            }
        }
        
        return count
    }
    
    private func countMorningFuelDays() -> Int {
        let calendar = Calendar.current
        var count = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }
            
            for meal in mealsOnDay {
                let hour = calendar.component(.hour, from: meal.timestamp)
                if hour < 10 {
                    count += 1
                    break
                }
            }
        }
        
        return count
    }
    
    private func calculateMealSpacingScore() -> Double {
        let calendar = Calendar.current
        var totalSpacing = 0.0
        var spacingCount = 0
        
        for dayOffset in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: Date()) else { continue }
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
            
            let mealsOnDay = nutrition.loggedMeals.filter {
                $0.timestamp >= startOfDay && $0.timestamp < endOfDay
            }.sorted { $0.timestamp < $1.timestamp }
            
            if mealsOnDay.count >= 2 {
                for i in 1..<mealsOnDay.count {
                    let spacing = mealsOnDay[i].timestamp.timeIntervalSince(mealsOnDay[i-1].timestamp)
                    totalSpacing += spacing
                    spacingCount += 1
                }
            }
        }
        
        guard spacingCount > 0 else { return 0 }
        let avgSpacing = totalSpacing / Double(spacingCount) / 3600.0 // Convert to hours
        // Ideal spacing is 3-5 hours
        if avgSpacing >= 3 && avgSpacing <= 5 {
            return 100
        } else if avgSpacing >= 2 && avgSpacing <= 6 {
            return 75
        } else if avgSpacing >= 1 && avgSpacing <= 8 {
            return 50
        } else {
            return 25
        }
    }
    
    private var challengeProgress: Double {
        return Double(challengeDaysCompleted) / Double(max(1, challengeTotalDays))
    }
    
    private var challengeDaysCompleted: Int {
        // Simplified - would need to track challenge progress
        // For now, use consistency score as proxy
        return min(nutrition.consistencyScore, challengeTotalDays)
    }
    
    private var challengeTotalDays: Int {
        // Most challenges are 3-5 days
        return 4
    }
    
    // Helper to get persona profile (simplified version)
    private func getPersonaProfile(for personaID: Int) -> PersonaProfile? {
        // This is a simplified lookup - in production, you'd load from WellnessSnapshot
        // For now, return a basic profile based on personaID
        switch personaID {
        case 1:
            return PersonaProfile(
                personaName: "The Under-eater + Weight Gainer",
                personaDescription: "We'll help you build strength with steady, simple meals.",
                challenges: ["Inconsistent meals", "Low appetite", "Busy schedule"],
                suggestedPattern: "3 meals + 1–2 snacks/day, calorie-dense but simple.",
                petChallenge: "Log 2 meals/day for 5 days.",
                personaType: 1
            )
        case 3:
            return PersonaProfile(
                personaName: "The Breakfast Skipper",
                personaDescription: "A morning meal will help stabilize your day.",
                challenges: ["Low morning appetite", "Night cravings"],
                suggestedPattern: "Add a morning snack or small meal.",
                petChallenge: "Log anything before noon 3× this week.",
                personaType: 3
            )
        case 5:
            return PersonaProfile(
                personaName: "The Stress Snacker",
                personaDescription: "We'll help you balance stress-driven snacking.",
                challenges: ["Study snacking", "Cravings"],
                suggestedPattern: "3 meals + planned snack windows.",
                petChallenge: "Try avoiding late snacks 4 nights in a row.",
                personaType: 5
            )
        case 9:
            return PersonaProfile(
                personaName: "The Always-On-The-Go Student",
                personaDescription: "We'll help you stay fueled with portable options.",
                challenges: ["Rushed days", "Forgotten meals"],
                suggestedPattern: "Grab-and-go breakfasts, portable snacks.",
                petChallenge: "Log lunch 5× this week.",
                personaType: 9
            )
        case 10:
            return PersonaProfile(
                personaName: "The Overeater",
                personaDescription: "Balanced portions and timing will steady energy.",
                challenges: ["Portion size", "Late hunger"],
                suggestedPattern: "3 structured meals + early dinners.",
                petChallenge: "Log all meals before 9pm for 4 days.",
                personaType: 10
            )
        default:
            return PersonaProfile(
                personaName: "The Balanced Starter",
                personaDescription: "You're off to a strong start — consistent habits will help you thrive.",
                challenges: ["Staying consistent", "Busy lifestyle"],
                suggestedPattern: "3 balanced meals/day + 1 flexible snack.",
                petChallenge: "Log 2 meals/day for 4 days.",
                personaType: 13
            )
        }
    }
}

// MARK: - Preview
#Preview {
    let userData: UserData = {
        let data = UserData()
        data.name = "Janice"
        data.email = "test@example.com"
        return data
    }()
    
    return ProgressScreen(
        userData: userData,
        nutrition: NutritionState()
    )
}
