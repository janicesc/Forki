//
//  SignInScreen.swift
//  Forki
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI

struct SignInScreen: View {
    @Binding var currentScreen: Int
    @ObservedObject var userData: UserData
    var onSignInComplete: (() -> Void)? = nil
    
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showUsernameError: Bool = false
    @State private var showPasswordError: Bool = false
    @State private var usernameErrorMessage: String = ""
    @State private var passwordErrorMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case username, password
    }
    
    var body: some View {
        ZStack {
            // Background gradient (same as Home Screen)
            ForkiTheme.backgroundGradient
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerSection
                            .padding(.top, -5)
                        formSection
                            .forkiPanel()
                        footerSection
                    }
                    .frame(maxWidth: 420)
                    .padding(.horizontal, 24)
                    .padding(.top, 100)
                    .padding(.bottom, 200) // Extra padding for fixed buttons
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }
            
            // Fixed buttons overlay - not affected by keyboard
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.easeInOut) { currentScreen = 1 }
                        } label: {
                            Text("Sign Up")
                                .font(.system(size: 16, weight: .heavy, design: .rounded))
                                .foregroundColor(ForkiTheme.textPrimary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 18)
                                .background(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .fill(ForkiTheme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                                .stroke(ForkiTheme.borderPrimary.opacity(0.3), lineWidth: 2)
                                        )
                                )
                                .shadow(color: ForkiTheme.actionShadow, radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        Button {
                            validateForm()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            } else {
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 18)
                            }
                        }
                        .disabled(isLoading)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#8DD4D1"), Color(hex: "#6FB8B5")],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                                        .stroke(Color(hex: "#7AB8B5"), lineWidth: 4)
                                )
                        )
                        .foregroundColor(.white)
                        .shadow(color: ForkiTheme.actionShadow, radius: 10, x: 0, y: 6)
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Separate text below Sign Up button (centered to Sign Up button width)
                    HStack(spacing: 12) {
                        HStack {
                            Spacer()
                            Text("Don't have an account?")
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .italic()
                                .tracking(-0.5)
                                .foregroundColor(ForkiTheme.textSecondary.opacity(0.8))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Spacer for Sign In button area
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 80)
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .onAppear {
            // Clear all fields when screen appears (e.g., after sign out or navigation)
            username = ""
            password = ""
            showUsernameError = false
            showPasswordError = false
            usernameErrorMessage = ""
            focusedField = nil
        }
    }
    
    // MARK: Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome back!")
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
    
    // MARK: Form
    private var formSection: some View {
        VStack(spacing: 20) {
            // Email Input (used as username for Supabase Auth)
            VStack(alignment: .leading, spacing: 6) {
                SignInStyledTextField(
                    title: "Email",
                    placeholder: "your@email.com",
                    text: $username,
                    isError: showUsernameError,
                    focusedField: $focusedField,
                    fieldType: .username
                )
                .onChange(of: username) { _, newValue in
                    // Clear error state when email becomes valid
                    if !newValue.trimmingCharacters(in: .whitespaces).isEmpty && isValidEmail(newValue) {
                        showUsernameError = false
                        usernameErrorMessage = ""
                    }
                }
                
                if showUsernameError {
                    errorMessage(usernameErrorMessage.isEmpty ? "Please fill out this field." : usernameErrorMessage)
                }
            }
            
            // Password Input
            VStack(alignment: .leading, spacing: 6) {
                SignInStyledTextField(
                    title: "Password",
                    placeholder: "Value",
                    text: $password,
                    isError: showPasswordError,
                    focusedField: $focusedField,
                    fieldType: .password,
                    isSecure: true
                )
                .onChange(of: password) { _, newValue in
                    // Clear error state when password becomes valid
                    if isValidPassword(newValue) {
                        showPasswordError = false
                        passwordErrorMessage = ""
                    }
                }
                
                if showPasswordError {
                    // Show error message - either authentication error or validation error
                    errorMessage(passwordErrorMessage.isEmpty ? "Must be 6 or more characters and at least 1 special character" : passwordErrorMessage)
                } else {
                    // Show requirements as helper text
                    Text("Must be 6 or more characters and at least 1 special character")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(ForkiTheme.textSecondary.opacity(0.7))
                        .padding(.leading, 5)
                        .padding(.top, 2)
                }
            }
        }
    }
    
    // MARK: Footer
    private var footerSection: some View {
        HStack(spacing: 0) {
            Text("By continuing, you agree to our ")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(ForkiTheme.textSecondary.opacity(0.8))
            
            Button(action: {
                showTerms = true
            }) {
                Text("Terms")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.borderPrimary)
            }
            
            Text(" & ")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(ForkiTheme.textSecondary.opacity(0.8))
            
            Button(action: {
                showPrivacy = true
            }) {
                Text(" Privacy Policy")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(ForkiTheme.borderPrimary)
            }
            
            Text(".")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundColor(ForkiTheme.textSecondary.opacity(0.8))
        }
        .multilineTextAlignment(.center)
        .sheet(isPresented: $showTerms) {
            TermsOfServiceView(onDismiss: {
                showTerms = false
            })
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacyPolicyView(onDismiss: {
                showPrivacy = false
            })
        }
    }
    
    // MARK: Validation
    private func validateForm() {
        var isValid = true
        
        // Reset errors
        showUsernameError = false
        showPasswordError = false
        usernameErrorMessage = ""
        passwordErrorMessage = ""
        
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            showUsernameError = true
            usernameErrorMessage = "Please fill out this field."
            isValid = false
        } else if !isValidEmail(username) {
            showUsernameError = true
            usernameErrorMessage = "Please enter a valid email address."
            isValid = false
        }
        
        if password.isEmpty {
            showPasswordError = true
            isValid = false
        } else if !isValidPassword(password) {
            showPasswordError = true
            isValid = false
        }
        
        if isValid {
            isLoading = true
            
            // Sign in with Supabase
            Task {
                do {
                    let (userId, session) = try await SupabaseAuthService.shared.signIn(
                        username: username,
                        password: password
                    )
                    
                    // Save session
                    SupabaseAuthService.shared.saveSession(session)
                    
                    // Load user data from Supabase (use session token for authentication)
                    if let loadedUserData = try await SupabaseAuthService.shared.loadUserData(userId: userId, accessToken: session.accessToken) {
                        await MainActor.run {
                            // Update local userData with Supabase data
                            userData.name = loadedUserData.name
                            userData.email = loadedUserData.email
                            userData.age = loadedUserData.age
                            userData.gender = loadedUserData.gender
                            userData.height = loadedUserData.height
                            userData.weight = loadedUserData.weight
                            userData.goal = loadedUserData.goal
                            userData.goalDuration = loadedUserData.goalDuration
                            userData.foodPreferences = loadedUserData.foodPreferences
                            userData.notifications = loadedUserData.notifications
                            userData.selectedCharacter = loadedUserData.selectedCharacter
                            userData.personaID = loadedUserData.personaID
                            userData.recommendedCalories = loadedUserData.recommendedCalories
                            userData.eatingPattern = loadedUserData.eatingPattern
                            userData.BMI = loadedUserData.BMI
                            userData.bodyType = loadedUserData.bodyType
                            userData.metabolism = loadedUserData.metabolism
                            userData.recommendedMacros = loadedUserData.recommendedMacros
                            
                            // Also save locally (continue to save userData as we already do)
                            UserDefaults.standard.set(username, forKey: "hp_userEmail")
                            UserDefaults.standard.set(userData.name, forKey: "hp_userName")
                            UserDefaults.standard.set(userId, forKey: "supabase_user_id")
                            UserDefaults.standard.set(loadedUserData.personaID, forKey: "hp_personaID")
                            UserDefaults.standard.set(loadedUserData.recommendedCalories, forKey: "hp_recommendedCalories")
                            
                            // Initialize nutrition state with persona and calories to restore avatar state
                            if loadedUserData.personaID > 0 && loadedUserData.recommendedCalories > 0 {
                                userData.nutrition.initializeFromSnapshot(
                                    personaID: loadedUserData.personaID,
                                    recommendedCalories: loadedUserData.recommendedCalories
                                )
                            }
                        }
                    } else {
                        // User exists but no profile data yet, use defaults
                        await MainActor.run {
                            userData.email = username
                            UserDefaults.standard.set(username, forKey: "hp_userEmail")
                            UserDefaults.standard.set(userId, forKey: "supabase_user_id")
                        }
                    }
                    
                    await MainActor.run {
                        isLoading = false
                        
                        // Always navigate to Home Screen after successful sign in
                        // The user's data and session are now loaded
                        UserDefaults.standard.set(true, forKey: "hp_isSignedIn")
                        UserDefaults.standard.set(true, forKey: "hp_hasOnboarded") // Mark as onboarded if they have data
                        
                        // Navigate to Home Screen (screen 6)
                        withAnimation(.easeInOut) { 
                            currentScreen = 6 
                        }
                    }
                } catch let error as SupabaseAuthService.AuthError {
                    await MainActor.run {
                        isLoading = false
                        
                        switch error {
                        case .userNotFound:
                            showUsernameError = true
                            usernameErrorMessage = "No account found with this email. Want to sign up?"
                            showPasswordError = false
                            passwordErrorMessage = ""
                        case .invalidCredentials:
                            showPasswordError = true
                            passwordErrorMessage = "Incorrect password. Try again?"
                            showUsernameError = false
                            usernameErrorMessage = ""
                        default:
                            showPasswordError = true
                            passwordErrorMessage = error.errorDescription ?? "An error occurred. Please try again."
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        showPasswordError = true
                        passwordErrorMessage = "An error occurred. Please try again."
                    }
                }
            }
        }
    }
    
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return email.range(of: emailRegex, options: .regularExpression) != nil
    }
    
    private func isValidPassword(_ password: String) -> Bool {
        // Must be 6 or more characters and at least 1 special character
        guard password.count >= 6 else { return false }
        let specialCharacterRegex = #"[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]"#
        return password.range(of: specialCharacterRegex, options: .regularExpression) != nil
    }
    
    // MARK: Error UI
    private func errorMessage(_ message: String) -> some View {
        HStack(alignment: .center, spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(ForkiTheme.highlightText)
                .font(.system(size: 14))
            Text(message)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(ForkiTheme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.leading, 5)
        .padding(.top, 2)
    }
}

// MARK: - SignInStyledTextField
struct SignInStyledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isError: Bool
    @FocusState.Binding var focusedField: SignInScreen.Field?
    let fieldType: SignInScreen.Field
    var isSecure: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(ForkiTheme.textPrimary)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(ForkiTheme.textSecondary.opacity(0.4))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                
                Group {
                    if isSecure {
                        SecureField("", text: $text)
                            .focused($focusedField, equals: fieldType)
                    } else {
                        TextField("", text: $text)
                            .focused($focusedField, equals: fieldType)
                    }
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .foregroundColor(ForkiTheme.textPrimary)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .background(ForkiTheme.surface)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isError ? ForkiTheme.highlightText :
                                (focusedField == fieldType ? ForkiTheme.borderPrimary : ForkiTheme.borderPrimary.opacity(0.3)),
                            lineWidth: isError ? 2 : 1.5
                        )
                )
                .accentColor(ForkiTheme.highlightText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            }
        }
    }
}

#Preview {
    SignInScreen(
        currentScreen: .constant(0),
        userData: UserData()
    )
}

