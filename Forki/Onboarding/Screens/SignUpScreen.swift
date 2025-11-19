//
//  SignUpScreen.swift
//  Forki
//
//  Created by Janice C on 9/16/25.
//

import SwiftUI

struct SignUpScreen: View {
    @Binding var currentScreen: Int
    @ObservedObject var userData: UserData   // custom model for name/email
    var onSignUpComplete: (() -> Void)? = nil
    
    @State private var name: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showNameError: Bool = false
    @State private var showUsernameError: Bool = false
    @State private var showPasswordError: Bool = false
    @State private var usernameErrorMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var showTerms: Bool = false
    @State private var showPrivacy: Bool = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, username, password
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
                    .padding(.top, 80)
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
                            withAnimation(.easeInOut) { currentScreen = 2 }
                        } label: {
                            Text("Sign In")
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
                                Text("Sign Up")
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
                    
                    // Separate text below Sign In button (centered to Sign In button width)
                    HStack(spacing: 12) {
                        HStack {
                            Spacer()
                            Text("Already have an account?")
                                .font(.system(size: 13, weight: .medium, design: .default))
                                .italic()
                                .tracking(-0.5)
                                .foregroundColor(ForkiTheme.textSecondary.opacity(0.8))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        
                        // Spacer for Sign Up button area
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
            name = ""
            username = ""
            password = ""
            showNameError = false
            showUsernameError = false
            showPasswordError = false
            usernameErrorMessage = ""
            focusedField = nil
        }
    }
    
    // MARK: Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hi there!")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
                
                Text("Let's get started.")
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundColor(ForkiTheme.textPrimary)
            }
            
            Text("Tell us a bit about yourself")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundColor(ForkiTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
    }
    
    // MARK: Form
    private var formSection: some View {
        VStack(spacing: 20) {
            // Name Input
            VStack(alignment: .leading, spacing: 6) {
                StyledTextField(
                    title: "Name",
                    placeholder: "Value",
                    text: $name,
                    isError: showNameError,
                    focusedField: $focusedField,
                    fieldType: .name
                )
                
                if showNameError {
                    errorMessage("Please fill out this field.")
                }
            }
            
            // Email Input (used as username for Supabase Auth)
            VStack(alignment: .leading, spacing: 6) {
                StyledTextField(
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
                StyledTextField(
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
                    // Use basic validation for real-time clearing (Supabase may have stricter requirements)
                    if isValidPassword(newValue) {
                        showPasswordError = false
                    }
                }
                
                if showPasswordError {
                    errorMessage("Must be 6 or more characters and at least 1 special character")
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
        // Clear all previous errors first
        showNameError = false
        showUsernameError = false
        showPasswordError = false
        usernameErrorMessage = ""
        
        var isValid = true
        
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            showNameError = true
            isValid = false
        }
        
        if username.trimmingCharacters(in: .whitespaces).isEmpty {
            showUsernameError = true
            usernameErrorMessage = "Please fill out this field."
            isValid = false
        } else if !isValidEmail(username) {
            showUsernameError = true
            usernameErrorMessage = "Please enter a valid email address."
            isValid = false
        }
        
        if !isValidPassword(password) {
            showPasswordError = true
            isValid = false
        }
        
        if isValid {
            isLoading = true
            
            // Sign up with Supabase
            Task {
                do {
                    let (userId, session) = try await SupabaseAuthService.shared.signUp(
                        username: username,
                        password: password,
                        name: name
                    )
                    
                    // Save session only if it's valid (has real tokens)
                    // If session is "pending", it means user was created but no session was returned
                    // This is fine - user can proceed to onboarding and sign in later if needed
                    if !session.accessToken.isEmpty && session.accessToken != "pending" {
                        SupabaseAuthService.shared.saveSession(session)
                    } else {
                        print("ℹ️ No session to save - user created successfully, proceeding to onboarding")
                    }
                    
                    // Save user data to Supabase users table
                    // Note: A database trigger will automatically create the row in public.users
                    // when the user is created in auth.users. We'll update it with the name here.
                    do {
                        // Create a temporary UserData with signup info
                        let tempUserData = UserData()
                        tempUserData.name = name
                        tempUserData.email = username
                        
                        // Use session token if available for authentication
                        let token = session.accessToken.isEmpty || session.accessToken == "pending" ? nil : session.accessToken
                        
                        try await SupabaseAuthService.shared.saveUserData(
                            userId: userId,
                            userData: tempUserData,
                            accessToken: token
                        )
                        print("✅ User data saved to Supabase")
                    } catch {
                        print("⚠️ Failed to save user data to Supabase: \(error)")
                        // The database trigger should have created the row automatically
                        // We'll update it after onboarding or on next sign in
                    }
                    
                    // Update local userData
                    await MainActor.run {
                        isLoading = false
                        userData.updateName(name)
                        userData.email = username
                        
                        // Save email locally (continue to save userData as we already do)
                        UserDefaults.standard.set(username, forKey: "hp_userEmail")
                        UserDefaults.standard.set(userId, forKey: "supabase_user_id")
                        
                        // Call completion handler to start onboarding
                        onSignUpComplete?()
                    }
                } catch let error as SupabaseAuthService.AuthError {
                    await MainActor.run {
                        isLoading = false
                        // Clear all validation errors first - we'll show the auth error instead
                        showNameError = false
                        showPasswordError = false
                        
                        // Show error message based on error type
                        switch error {
                        case .emailAlreadyExists:
                            // Only show duplicate email error - account exists in Supabase
                            showUsernameError = true
                            usernameErrorMessage = "This email is already registered. Log in instead?"
                        case .userNotFound:
                            // This shouldn't happen on signup, but handle it
                            showUsernameError = true
                            usernameErrorMessage = "Please fill out this field."
                        case .invalidCredentials:
                            // This shouldn't happen on signup, but handle it
                            showPasswordError = true
                            print("Invalid credentials error during sign up")
                        case .networkError(let message):
                            // Show network errors on password field with message
                            showPasswordError = true
                            print("Network error during sign up: \(message)")
                        case .unknownError(let message):
                            // Show unknown errors - could be password requirements or other issues
                            showPasswordError = true
                            print("Sign up error: \(message)")
                        }
                    }
                } catch {
                    await MainActor.run {
                        isLoading = false
                        showPasswordError = true
                        print("Unexpected error during sign up: \(error)")
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
        // Note: Supabase may have additional requirements (uppercase, lowercase, numbers)
        guard password.count >= 6 else { return false }
        let specialCharacterRegex = #"[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]"#
        return password.range(of: specialCharacterRegex, options: .regularExpression) != nil
    }
    
    // Helper to check if password meets Supabase's stricter requirements
    private func meetsSupabaseRequirements(_ password: String) -> Bool {
        // Check for uppercase
        let hasUppercase = password.range(of: #"[A-Z]"#, options: .regularExpression) != nil
        // Check for lowercase
        let hasLowercase = password.range(of: #"[a-z]"#, options: .regularExpression) != nil
        // Check for digit
        let hasDigit = password.range(of: #"[0-9]"#, options: .regularExpression) != nil
        // Check for special character
        let hasSpecial = password.range(of: #"[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]"#, options: .regularExpression) != nil
        
        return hasUppercase && hasLowercase && hasDigit && hasSpecial && password.count >= 6
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

// MARK: - StyledTextField
struct StyledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var isError: Bool
    @FocusState.Binding var focusedField: SignUpScreen.Field?
    let fieldType: SignUpScreen.Field
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
                .textInputAutocapitalization(fieldType == .name ? .words : .never)
                .disableAutocorrection(true)
            }
        }
    }
}

#Preview {
    SignUpScreen(
        currentScreen: .constant(1),
        userData: UserData()
    )
}

