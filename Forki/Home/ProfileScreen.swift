//
//  ProfileScreen.swift
//  Forki
//
//  Created by Janice C on 9/23/25.
//

import SwiftUI

struct ProfileScreen: View {
    let userData: UserData
    @ObservedObject var nutrition: NutritionState
    
    var onDismiss: (() -> Void)? = nil
    var onHome: (() -> Void)? = nil
    var onExplore: (() -> Void)? = nil
    var onCamera: (() -> Void)? = nil
    var onProgress: (() -> Void)? = nil
    var onRetakeQuiz: (() -> Void)? = nil
    var onSignOut: (() -> Void)? = nil
    var onPrivacyPolicy: (() -> Void)? = nil
    var onTermsConditions: (() -> Void)? = nil
    
    @State private var showSettingsMenu = false
    @State private var snapshot: WellnessSnapshot?
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfService = false
    @State private var showOnboarding = false
    @State private var showEditName = false
    @State private var editedName: String = ""
    
    init(userData: UserData, nutrition: NutritionState? = nil, onDismiss: (() -> Void)? = nil, onHome: (() -> Void)? = nil, onExplore: (() -> Void)? = nil, onCamera: (() -> Void)? = nil, onProgress: (() -> Void)? = nil, onRetakeQuiz: (() -> Void)? = nil, onSignOut: (() -> Void)? = nil, onPrivacyPolicy: (() -> Void)? = nil, onTermsConditions: (() -> Void)? = nil) {
        self.userData = userData
        self.onDismiss = onDismiss
        self.onHome = onHome
        self.onExplore = onExplore
        self.onCamera = onCamera
        self.onProgress = onProgress
        self.onRetakeQuiz = onRetakeQuiz
        self.onSignOut = onSignOut
        self.onPrivacyPolicy = onPrivacyPolicy
        self.onTermsConditions = onTermsConditions
        
        // Use provided nutrition or create a default one
        if let nutrition = nutrition {
            self._nutrition = ObservedObject(wrappedValue: nutrition)
        } else {
            // Initialize NutritionState to get avatar state - create a temporary one
            // This will be replaced by a @StateObject in the body if needed
            let personaID = UserDefaults.standard.integer(forKey: "hp_personaID")
            let recommendedCalories = UserDefaults.standard.integer(forKey: "hp_recommendedCalories")
            let goal = recommendedCalories > 0 ? recommendedCalories : 2000
            
            let nutritionState = NutritionState(goal: goal)
            nutritionState.personaID = personaID > 0 ? personaID : 13
            self._nutrition = ObservedObject(wrappedValue: nutritionState)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content
            ZStack {
                ForkiTheme.backgroundGradient
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header with Settings
                        ZStack {
                            // Left side - Back button
                            HStack {
                                Button {
                                    if let onDismiss = onDismiss {
                                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                            onDismiss()
                                        }
                                    }
                                } label: {
                                    Image(systemName: "arrow.left")
                                        .font(.title2)
                                        .foregroundColor(ForkiTheme.textPrimary)
                                }
                                
                                Spacer()
                            }
                            
                            // Center - Profile title (always centered)
                            Text("Profile")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                            
                            // Right side - Settings Icon / Sign Out Button
                            HStack {
                                Spacer()
                                
                                // Fixed width container to prevent layout shift
                                ZStack {
                                    // Settings Icon (hidden when Sign Out is shown)
                                    Button {
                                        // Toggle to show Sign Out UI
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            showSettingsMenu = true
                                        }
                                    } label: {
                                        Image(systemName: "gearshape")
                                            .font(.title2)
                                            .foregroundColor(ForkiTheme.textPrimary)
                                    }
                                    .opacity(showSettingsMenu ? 0 : 1)
                                    .scaleEffect(showSettingsMenu ? 0.8 : 1.0)
                                    .frame(width: 120, alignment: .trailing) // Fixed width
                                    
                                    // Sign Out Button (hidden when Settings is shown)
                                    Button {
                                        // Execute sign out
                                        showSettingsMenu = false
                                        if let onSignOut = onSignOut {
                                            onSignOut()
                                        }
                                    } label: {
                                        HStack(spacing: 6) {
                                            Image(systemName: "arrow.right.square")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Sign Out")
                                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                                .lineLimit(1)
                                        }
                                        .foregroundColor(ForkiTheme.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .fill(ForkiTheme.panelBackground)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(ForkiTheme.borderPrimary.opacity(0.6), lineWidth: 2)
                                        )
                                    }
                                    .opacity(showSettingsMenu ? 1 : 0)
                                    .scaleEffect(showSettingsMenu ? 1.0 : 0.8)
                                    .frame(width: 120, alignment: .trailing) // Fixed width, same as Settings
                                }
                                .frame(width: 120, alignment: .trailing) // Fixed container width
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 20)
                        .zIndex(10)
                        
                        // Main Profile Container
                        mainProfileContainer
                            .padding(.horizontal, 16)
                        
                        // Privacy Policy & Terms
                        VStack(spacing: 16) {
                            // Privacy Policy
                            Button {
                                showPrivacyPolicy = true
                            } label: {
                                HStack {
                                    Text("Privacy Policy")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(ForkiTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(ForkiTheme.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(ForkiTheme.panelBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(ForkiTheme.borderPrimary.opacity(0.5), lineWidth: 2)
                                )
                            }
                            
                            // Terms & Conditions
                            Button {
                                showTermsOfService = true
                            } label: {
                                HStack {
                                    Text("Terms & Conditions")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(ForkiTheme.textPrimary)
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(ForkiTheme.textSecondary)
                                }
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(ForkiTheme.panelBackground)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(ForkiTheme.borderPrimary.opacity(0.5), lineWidth: 2)
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer().frame(height: 100) // room for bottom bar
                    }
                    .padding(.bottom, 20)
                }
            }
            
            // Bottom Navigation Bar
            universalNavigationBar
                .padding(.horizontal, 12)
                .padding(.bottom, 2)
                .background(ForkiTheme.panelBackground.ignoresSafeArea(edges: .bottom))
        }
        .onTapGesture {
            // Dismiss settings menu when tapping outside
            if showSettingsMenu {
                withAnimation {
                    showSettingsMenu = false
                }
            }
        }
        .onAppear {
            calculateSnapshot()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView(onDismiss: {
                showPrivacyPolicy = false
            })
        }
        .sheet(isPresented: $showTermsOfService) {
            TermsOfServiceView(onDismiss: {
                showTermsOfService = false
            })
        }
        .sheet(isPresented: $showEditName) {
            EditNameView(name: $editedName, onSave: {
                if !editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    userData.updateName(editedName.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                showEditName = false
            }, onDismiss: {
                showEditName = false
            })
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowWrapper(
                userData: userData,
                nutrition: nutrition,
                onDismiss: {
                    showOnboarding = false
                }
            ) { onboardingData in
                // Convert OnboardingData to UserData and update
                let convertedUserData = onboardingData.toUserData()
                userData.age = convertedUserData.age
                userData.gender = convertedUserData.gender
                userData.height = convertedUserData.height
                userData.weight = convertedUserData.weight
                userData.goal = convertedUserData.goal
                userData.foodPreferences = convertedUserData.foodPreferences
                userData.notifications = convertedUserData.notifications
                userData.selectedCharacter = convertedUserData.selectedCharacter
                
                // Update persona ID and recommended calories
                let personaID = onboardingData.personaIDValue
                if personaID > 0 {
                    userData.personaID = personaID
                    UserDefaults.standard.set(personaID, forKey: "hp_personaID")
                    nutrition.personaID = personaID
                }
                
                let snapshot = WellnessSnapshotCalculator.calculateSnapshot(from: onboardingData)
                UserDefaults.standard.set(snapshot.recommendedCalories, forKey: "hp_recommendedCalories")
                nutrition.setGoal(snapshot.recommendedCalories)
                
                // Save updated data
                UserDefaults.standard.set(true, forKey: "hp_isSignedIn")
                UserDefaults.standard.set(true, forKey: "hp_hasOnboarded")
                
                // Dismiss onboarding and navigate to Home Screen
                showOnboarding = false
                if let onHome = onHome {
                    onHome()
                } else if let onDismiss = onDismiss {
                    onDismiss()
                }
            }
        }
    }
}

// MARK: - OnboardingFlow Wrapper
private struct OnboardingFlowWrapper: View {
    @ObservedObject var userData: UserData
    @ObservedObject var nutrition: NutritionState
    var onDismiss: (() -> Void)? = nil
    let onComplete: (OnboardingData) -> Void
    
    var body: some View {
        // OnboardingFlow automatically starts at step 0 (AgeGenderScreen)
        // since OnboardingNavigator.currentStep defaults to 0
        OnboardingFlow(userData: userData, onComplete: onComplete, onDismiss: onDismiss)
    }
}

extension ProfileScreen {
    // MARK: - Main Profile Container
    private var mainProfileContainer: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 24) {
                // Avatar Circle with profile icon frame
                ZStack {
                    // Profile icon as circle frame - same color as HomeScreen
                    Image(systemName: "person.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(ForkiTheme.avatarRing.opacity(0.6))
                    
                    // Avatar video masked to circle
                    AvatarView(
                        state: nutrition.avatarState,
                        showFeedingEffect: .constant(false),
                        size: 120
                    )
                    .mask(
                        Circle()
                            .frame(width: 110, height: 110)
                    )
                    .frame(width: 110, height: 110)
                }
                
                // User Name with Edit Icon
                ZStack {
                    // Center - Name (always centered)
                    Text(userData.name)
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                    
                    // Pencil icon positioned 6px to the right of the name
                    HStack(spacing: 0) {
                        // Invisible spacer to match name width
                        Text(userData.name)
                            .font(.system(size: 20, weight: .heavy, design: .rounded))
                            .opacity(0)
                        
                        Button {
                            editedName = userData.name
                            showEditName = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ForkiTheme.textSecondary)
                        }
                        .padding(.leading, 24)
                    }
                }
                .frame(maxWidth: .infinity)
                
                // Age, Gender, Height, Weight, Body Type, BMI, Metabolism - Two column layout
                VStack(alignment: .leading, spacing: 16) {
                    // Row 1: Age (left) | Gender (right)
                    HStack(alignment: .top, spacing: 20) {
                        // Age on left
                        if !userData.age.isEmpty {
                            EmojiProfileRow(icon: "calendar", label: "Age", value: userData.age)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Gender on right
                        if !userData.gender.isEmpty {
                            EmojiProfileRow(icon: "person.fill", label: "Gender", value: userData.gender.capitalized)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Row 2: Height (left) | Weight (right)
                    HStack(alignment: .top, spacing: 20) {
                        // Height on left
                        if !userData.height.isEmpty {
                            let heightInCm = Int(userData.height) ?? 0
                            let (feet, inches) = cmToFeetInches(cm: CGFloat(heightInCm))
                            EmojiProfileRow(icon: "ruler", label: "Height", value: "\(feet)′\(inches)″ (\(heightInCm) cm)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Weight on right
                        if !userData.weight.isEmpty {
                            let weightInKg = Int(userData.weight) ?? 0
                            let weightInLbs = Int(CGFloat(weightInKg) * 2.20462)
                            EmojiProfileRow(icon: "scalemass", label: "Weight", value: "\(weightInLbs) lbs (\(weightInKg) kg)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Row 3: Body Type (left) | BMI (right)
                    HStack(alignment: .top, spacing: 20) {
                        // Body Type on left
                        if let bodyType = snapshot?.bodyType {
                            EmojiProfileRow(icon: "person.fill", label: "Body Type", value: bodyType)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                        
                        // BMI on right
                        if let bmi = snapshot?.BMI {
                            EmojiProfileRow(icon: "chart.bar.fill", label: "BMI", value: String(format: "%.1f", bmi))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Row 4: Metabolism (left) | (right empty)
                    HStack(alignment: .top, spacing: 20) {
                        // Metabolism on left
                        if let metabolism = snapshot?.metabolism {
                            EmojiProfileRow(icon: "flame.fill", label: "Metabolism", value: metabolism)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Spacer()
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Right side empty
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Recommended Eating Pattern with icon
                if let pattern = snapshot?.persona.suggestedPattern {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(ForkiTheme.highlightText)
                            Text("Recommended Eating Pattern")
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                        }
                        
                        Text(pattern)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(ForkiTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // Edit button in top right corner
            Button {
                // Reset onboarding navigator to start from beginning (case 0)
                showOnboarding = true
            } label: {
                Text("Edit")
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                    .underline()
            }
            .padding(.top, 8)
            .padding(.trailing, 8)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(ForkiTheme.panelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 3)
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.12), radius: 14, x: 0, y: 8)
    }
    
    // MARK: - Helper Views
    private struct EmojiProfileRow: View {
        let icon: String
        let label: String
        let value: String
        
        var body: some View {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundColor(ForkiTheme.textSecondary)
                    .frame(width: 28, height: 28, alignment: .center)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .foregroundColor(ForkiTheme.textSecondary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                    
                    Text(value)
                        .foregroundColor(ForkiTheme.textPrimary)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    private func calculateSnapshot() {
        // Convert UserData to OnboardingData to calculate snapshot
        let onboardingData = OnboardingData()
        onboardingData.age = userData.age
        onboardingData.gender = GenderChoice(rawValue: userData.gender.lowercased())
        
        // Convert height (stored in cm) back to feet/inches for calculation
        if let heightCm = Int(userData.height) {
            onboardingData.heightCm = "\(heightCm)"
            onboardingData.heightUnit = .cm
        }
        
        // Convert weight (stored in kg) back for calculation
        if let weightKg = Int(userData.weight) {
            onboardingData.weightKg = "\(weightKg)"
            onboardingData.weightUnit = .kg
        }
        
        // Map goal back to primaryGoals
        let goal = userData.normalizedGoal.lowercased()
        if goal.contains("lose") {
            onboardingData.primaryGoals = ["lose_weight"]
        } else if goal.contains("gain") || goal.contains("build muscle") {
            onboardingData.primaryGoals = ["gain_weight"]
        } else if goal.contains("maintain") {
            onboardingData.primaryGoals = ["maintain_weight"]
        } else if goal.contains("habits") {
            onboardingData.primaryGoals = ["improve_habits"]
        } else if goal.contains("energy") || goal.contains("stress") {
            onboardingData.primaryGoals = ["boost_energy"]
        }
        
        // Get persona ID from UserDefaults
        let personaID = UserDefaults.standard.integer(forKey: "hp_personaID")
        onboardingData.personaIDValue = personaID > 0 ? personaID : 13
        
        // Calculate snapshot
        snapshot = WellnessSnapshotCalculator.calculateSnapshot(from: onboardingData)
    }
    
    private func calculateBMI() -> Double? {
        guard !userData.height.isEmpty, !userData.weight.isEmpty,
              let heightCm = Int(userData.height),
              let weightKg = Int(userData.weight) else {
            return nil
        }
        
        let heightInMeters = Double(heightCm) / 100.0
        let weightInKgDouble = Double(weightKg)
        
        guard heightInMeters > 0 else { return nil }
        return weightInKgDouble / (heightInMeters * heightInMeters)
    }
    
    private func cmToFeetInches(cm: CGFloat) -> (Int, Int) {
        let inchesTotal = Int(round(cm / 2.54))
        let feet = inchesTotal / 12
        let inches = inchesTotal % 12
        return (feet, inches)
    }
    
    // MARK: - Navigation Bar
    private var universalNavigationBar: some View {
        UniversalNavigationBar(
            onHome: {
                if let onHome = onHome {
                    onHome()
                } else if let onDismiss = onDismiss {
                    onDismiss()
                }
            },
            onExplore: {
                if let onExplore = onExplore {
                    onExplore()
                }
            },
            onCamera: {
                if let onCamera = onCamera {
                    onCamera()
                }
            },
            onProgress: {
                if let onProgress = onProgress {
                    onProgress()
                }
            },
            onProfile: { /* Already on profile */ },
            currentScreen: .profile
        )
    }
}

// MARK: - Edit Name View
private struct EditNameView: View {
    @Binding var name: String
    let onSave: () -> Void
    let onDismiss: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        ZStack {
            ForkiTheme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Navigation Bar
                HStack {
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(ForkiTheme.textPrimary)
                    }
                    
                    Spacer()
                    
                    Text("Edit Name")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundColor(ForkiTheme.textPrimary)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 16)
                
                // Content
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Name")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(ForkiTheme.textSecondary)
                        
                        TextField("Enter your name", text: $name)
                            .font(.system(size: 18, weight: .medium, design: .rounded))
                            .foregroundColor(ForkiTheme.textPrimary)
                            .textFieldStyle(.plain)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(ForkiTheme.panelBackground)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(ForkiTheme.borderPrimary.opacity(0.5), lineWidth: 2)
                            )
                            .focused($isTextFieldFocused)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.words)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    Spacer()
                    
                    // Save Button - matches Intro Screen "Let's Get Started" button
                    Button {
                        onSave()
                    } label: {
                        Text("Save")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color(hex: "#8DD4D1"), Color(hex: "#6FB8B5")], // Mint gradient - same as Log Food button
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                                            .stroke(Color(hex: "#7AB8B5"), lineWidth: 4) // Border color for mint button
                                    )
                            )
                            .shadow(color: ForkiTheme.actionShadow, radius: 10, x: 0, y: 6)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .onAppear {
            // Focus text field when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}


