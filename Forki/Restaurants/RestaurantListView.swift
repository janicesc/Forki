//
//  RestaurantListView.swift
//  Forki
//
//  Restaurant listing page - Explore screen
//

import SwiftUI

struct RestaurantListView: View {
    @State private var restaurants: [Restaurant] = RestaurantData.mockRestaurants
    @State private var searchText: String = ""
    @State private var selectedRestaurant: Restaurant?
    @State private var locationEnabled: Bool = true // Default to enabled for USC campus
    @State private var currentLocation: String = "University Park, Los Angeles"
    
    let onDismiss: () -> Void
    let onLogFood: (FoodItem) -> Void
    var onHome: (() -> Void)? = nil
    var onProgress: (() -> Void)? = nil
    var onProfile: (() -> Void)? = nil
    var onCamera: (() -> Void)? = nil
    
    var filteredRestaurants: [Restaurant] {
        if searchText.isEmpty {
            return restaurants
        }
        return restaurants.filter { restaurant in
            restaurant.name.localizedCaseInsensitiveContains(searchText) ||
            restaurant.cuisine.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color.white,
                    Color(hex: "#F5F7FA"),
                    Color(hex: "#E8ECF1")
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Section - matching "My Progress" style
                headerSection
                    .padding(.top, 8)
                    .padding(.bottom, 16)
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Color(hex: "#9CA3AF"))
                    
                    TextField("Search restaurants...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(Color(hex: "#1A2332"))
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ForkiTheme.borderPrimary.opacity(0.3), lineWidth: 2)
                        )
                )
                .shadow(color: ForkiTheme.borderPrimary.opacity(0.1), radius: 8, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 0)
                
                // Location Status Card
                HStack(spacing: 12) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(locationEnabled ? ForkiTheme.actionLogFood : Color(hex: "#9CA3AF"))
                    
                    Text(locationEnabled ? currentLocation : "Enable location")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color(hex: "#1A2332"))
                    
                    Spacer()
                    
                    if !locationEnabled {
                        Button(action: {
                            // Request location permission
                            locationEnabled = true
                        }) {
                            Text("Enable")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(ForkiTheme.actionLogFood)
                                )
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 2)
                        )
                )
                .shadow(color: ForkiTheme.borderPrimary.opacity(0.08), radius: 6, x: 0, y: 2)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)
                
                // Restaurant count header
                HStack {
                    Text("\(filteredRestaurants.count) restaurants nearby")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(ForkiTheme.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 21) // 16 + 5px to the right
                .padding(.bottom, 8)
                
                // Restaurant list
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredRestaurants) { restaurant in
                            RestaurantCard(restaurant: restaurant) {
                                selectedRestaurant = restaurant
                            }
                        }
                        
                        if filteredRestaurants.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 48))
                                    .foregroundColor(Color(hex: "#9CA3AF"))
                                Text("No restaurants found")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(Color(hex: "#6B7280"))
                            }
                            .padding(.vertical, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                    .padding(.bottom, 80) // Add bottom padding to account for nav bar
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                // Bottom Navigation Bar - docked to bottom, unaffected by keyboard
                universalNavigationBar
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)
                    .background(ForkiTheme.panelBackground.ignoresSafeArea(edges: .bottom))
            }
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .overlay(
                // Purple outline around the container
                RoundedRectangle(cornerRadius: 0, style: .continuous)
                    .stroke(ForkiTheme.borderPrimary, lineWidth: 4)
                    .ignoresSafeArea()
            )
        }
        .sheet(isPresented: Binding(
            get: { selectedRestaurant != nil },
            set: { if !$0 { selectedRestaurant = nil } }
        )) {
            if let restaurant = selectedRestaurant {
                RestaurantDetailView(
                    restaurant: restaurant,
                    onDismiss: { selectedRestaurant = nil },
                    onLogFood: onLogFood
                )
            }
        }
    }
    
    // MARK: - Header Section (matching "My Progress" style)
    private var headerSection: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        onDismiss()
                    }
                } label: {
                    Image(systemName: "arrow.left")
                        .font(.title2)
                        .foregroundColor(ForkiTheme.borderPrimary)
                }
                
                Spacer()
                
                Text("Find Food")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                
                Spacer()
                
                Color.clear
                    .frame(width: 24, height: 24)
            }
        }
        .padding(.horizontal, 16)
    }
    
    // MARK: - Navigation Bar
    private var universalNavigationBar: some View {
        UniversalNavigationBar(
            onHome: {
                if let onHome = onHome {
                    onHome()
                } else {
                    onDismiss()
                }
            },
            onExplore: { /* Already on explore screen */ },
            onCamera: {
                if let onCamera = onCamera {
                    onCamera()
                } else {
                    // Camera handled by parent - dismiss to allow HomeScreen to handle
                    onDismiss()
                }
            },
            onProgress: {
                if let onProgress = onProgress {
                    onProgress()
                }
            },
            onProfile: {
                if let onProfile = onProfile {
                    onProfile()
                }
            },
            currentScreen: .explore
        )
    }
}

