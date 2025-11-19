//
//  FoodLoggerView.swift
//  Forki
//

import SwiftUI
import Combine

// MARK: - Food Search ViewModel

final class FoodSearchViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchResults: [RapidSearch.LocalFood] = []

    private var cancellables = Set<AnyCancellable>()

    init() {
        $searchText
            .removeDuplicates()
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] query in
                guard let self = self else { return }
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    self.searchResults = []
                } else {
                    // RapidSearch.search is synchronous and safe to call on main thread
                    self.searchResults = RapidSearch.shared.search(trimmed)
                }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Food Logger View

struct FoodLoggerView: View {
    let prefill: FoodItem?
    let loggedMeals: [LoggedFood]
    let onSave: (LoggedFood) -> Void
    let onClose: () -> Void
    let onDeleteFromHistory: (UUID) -> Void
    let editId: UUID?                          // Existing log being edited, if any
    let onUpdate: ((UUID, LoggedFood) -> Void)? // For editing an existing log

    @Environment(\.dismiss) private var dismiss

    @State private var searchQuery: String = ""
    @State private var previousSearchQuery: String = ""
    @State private var searchResults: [RapidSearch.LocalFood] = []
    @State private var selectedFood: FoodItem? = nil
    @State private var showingLogHistory = false
    @State private var showingManualFoodLog = false

    @StateObject private var searchViewModel = FoodSearchViewModel()

    // Edit mode?
    private var isEditMode: Bool {
        editId != nil
    }

    // MARK: - Init

    init(
        prefill: FoodItem? = nil,
        loggedMeals: [LoggedFood] = [],
        onSave: @escaping (LoggedFood) -> Void,
        onClose: @escaping () -> Void,
        onDeleteFromHistory: @escaping (UUID) -> Void,
        editId: UUID? = nil,
        onUpdate: ((UUID, LoggedFood) -> Void)? = nil
    ) {
        self.prefill = prefill
        self.loggedMeals = loggedMeals
        self.onSave = onSave
        self.onClose = onClose
        self.onDeleteFromHistory = onDeleteFromHistory
        self.editId = editId
        self.onUpdate = onUpdate

        // Initial state from prefill (if present)
        _selectedFood = State(initialValue: prefill)
        let initialQuery = prefill?.name ?? ""
        _searchQuery = State(initialValue: initialQuery)
        _previousSearchQuery = State(initialValue: initialQuery)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                backgroundGradient
                mainContent
            }
            .navigationTitle(isEditMode ? "Edit Log" : "Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.white.opacity(0.95), for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .task {
                if let p = prefill {
                    applyPrefill(p)
                    NSLog("📝 [FoodLogger] .task prefill='\(p.name)', cal=\(p.calories), id=\(p.id), editMode=\(isEditMode)")
                } else {
                    NSLog("⚠️ [FoodLogger] .task: NO PREFILL - will show popular foods")
                }
            }
            .onAppear {
                // CRITICAL: Always apply prefill on appear, especially for edit mode
                if let p = prefill {
                    applyPrefill(p)
                    NSLog("📝 [FoodLogger] onAppear prefill='\(p.name)', cal=\(p.calories), id=\(p.id), editMode=\(isEditMode)")
                }
                // Sync search pipeline
                searchViewModel.searchText = searchQuery
            }
            .onChange(of: prefill) { newPrefill in
                if let p = newPrefill {
                    applyPrefill(p)
                    NSLog("📝 [FoodLogger] onChange(prefill) -> '\(p.name)', cal=\(p.calories)")
                }
            }
            .onChange(of: searchQuery) { newValue in
                // Feed query into RapidSearch via view model
                searchViewModel.searchText = newValue
                
                // If there's no prefill, handle search query changes
                if prefill == nil {
                    // If user clears the search query, return to default view (popular foods)
                    if newValue.isEmpty {
                        selectedFood = nil
                    } else if selectedFood != nil && newValue != previousSearchQuery {
                        // When user types a new/different search query, clear previously selected food
                        // so they can see new search results instead of the old selected food
                        selectedFood = nil
                    }
                }
                
                // Update previous search query for next comparison
                previousSearchQuery = newValue
            }
            .onChange(of: searchViewModel.searchResults) { newResults in
                // onChange is already on main thread
                searchResults = newResults
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingManualFoodLog = true
                    } label: {
                        ManualLogIcon()
                            .frame(width: 32, height: 32)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        onClose()
                        dismiss()
                    }
                    .foregroundColor(ForkiTheme.borderPrimary)
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showingLogHistory) {
            LogHistoryView(
                loggedMeals: loggedMeals,
                onDelete: { id in onDeleteFromHistory(id) },
                onSelect: { loggedFood in
                    selectedFood = loggedFood.food
                },
                onClose: { showingLogHistory = false },
                onUpdate: onUpdate
            )
        }
        .sheet(isPresented: $showingManualFoodLog) {
            NavigationStack {
                ScrollView {
                    ManualFoodLogView(
                        onSave: { loggedFood in
                            onSave(loggedFood)
                            showingManualFoodLog = false
                            onClose()
                            dismiss()
                        },
                        onCancel: {
                            showingManualFoodLog = false
                        }
                    )
                }
                .background(
                    LinearGradient(
                        colors: [
                            Color.white,
                            Color(hex: "#F5F7FA"),
                            Color(hex: "#E8ECF1")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .navigationTitle("Manual Food Log")
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(Color.white.opacity(0.95), for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Cancel") {
                            showingManualFoodLog = false
                        }
                        .foregroundColor(ForkiTheme.borderPrimary)
                        .font(.system(size: 16, weight: .semibold))
                    }
                }
            }
            .presentationDetents([.fraction(0.6), .large])
            .presentationDragIndicator(.visible)
        }
    }

    // MARK: - Prefill Handling

    /// Centralized helper so `.task`, `.onAppear`, and `.onChange(prefill)` stay in sync.
    private func applyPrefill(_ p: FoodItem) {
        // These are called from .task/.onAppear which are already on main thread
        selectedFood = p
        searchQuery = p.name
    }

    /// Option A behavior – prefill has priority, unless user explicitly selects something.
    /// 1. If `prefill` exists → Always use that as primary.
    /// 2. Else use `selectedFood` (from Popular / Search).
    private var foodToDisplay: FoodItem? {
        if let prefillFood = prefill {
            if selectedFood?.id != prefillFood.id {
                NSLog("📝 [FoodLogger] foodToDisplay: Using PREFILL '\(prefillFood.name)'")
            }
            return prefillFood
        } else if let selected = selectedFood {
            return selected
        } else {
            return nil
        }
    }

    // MARK: - View Components

    private var backgroundGradient: some View {
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
    }

    private var mainContent: some View {
        VStack(spacing: 0) {
            searchBarSection
            contentArea
        }
        .overlay(
            RoundedRectangle(cornerRadius: 0, style: .continuous)
                .stroke(ForkiTheme.borderPrimary, lineWidth: 4)
                .ignoresSafeArea()
        )
    }

    // MARK: Search Bar

    private var searchBarSection: some View {
        HStack(spacing: 12) {
            searchBar

            Button(action: { showingLogHistory = true }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(ForkiTheme.actionLogFood)
                    .frame(width: 44, height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ForkiTheme.borderPrimary.opacity(0.1))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ForkiTheme.borderPrimary.opacity(0.3), lineWidth: 2)
                            )
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(hex: "#9CA3AF"))

            TextField("Search for food items...", text: $searchQuery)
                .textFieldStyle(.plain)
                .foregroundColor(Color(hex: "#1A2332"))
                // Search logic is handled via Combine in FoodSearchViewModel
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
    }

    // MARK: Content Area (Option A behavior)

    @ViewBuilder
    private var contentArea: some View {
        if let food = foodToDisplay {
            // PREFILL (or selectedFood) always shown at top.
            VStack(spacing: 16) {
                prefilledFoodView(food: food)
                    .id(food.id) // force refresh

                // Hide search results when a food item is selected
                // Only show search results if there's NO prefill AND no food has been selected from search
            }
        } else {
            // No prefill:
            if !searchQuery.isEmpty {
                searchResultsSection
            } else {
                popularFoodsSection
            }
        }
    }

    // MARK: Prefilled / Selected Food View

    private func prefilledFoodView(food: FoodItem) -> some View {
        // Convert portion-adjusted food back to base values in edit mode
        // When a food is logged, it's stored with portion-adjusted values (calories * portion, etc.)
        // When editing, we need to convert back to base values (for 1.0 portion) so the slider works correctly
        let baseFood: FoodItem = {
            if isEditMode,
               let editId = editId,
               let loggedMeal = loggedMeals.first(where: { $0.id == editId }),
               loggedMeal.portion > 0.001 {

                // The food passed in has portion-adjusted values (already multiplied by portion)
                // Divide by the original portion to get base values (for 1.0 portion)
                let baseCalories = max(1, Int(Double(food.calories) / loggedMeal.portion))
                let baseProtein  = max(0.0, food.protein / loggedMeal.portion)
                let baseCarbs    = max(0.0, food.carbs   / loggedMeal.portion)
                let baseFats     = max(0.0, food.fats    / loggedMeal.portion)

                NSLog("📝 [FoodLogger] Converting portion-adjusted to base values:")
                NSLog("   Original (portion-adjusted): cal=\(food.calories), protein=\(food.protein), carbs=\(food.carbs), fats=\(food.fats)")
                NSLog("   Original portion: \(loggedMeal.portion)")
                NSLog("   Base values: cal=\(baseCalories), protein=\(baseProtein), carbs=\(baseCarbs), fats=\(baseFats)")

                return FoodItem(
                    id: food.id,
                    name: food.name,
                    calories: baseCalories,
                    protein: baseProtein,
                    carbs: baseCarbs,
                    fats: baseFats,
                    category: food.category,
                    usdaFood: food.usdaFood
                )
            } else {
                return food
            }
        }()

        return ScrollView {
            FoodDetailView(
                food: baseFood,
                isEditMode: isEditMode,
                editId: editId,
                initialPortion: isEditMode ? initialPortion : 1.0,
                loggedMeals: loggedMeals,
                onSave: { logged in
                    if let editId = editId, let onUpdate = onUpdate {
                        onUpdate(editId, logged)
                    } else {
                        onSave(logged)
                    }
                    onClose()
                    dismiss()
                },
                onCancel: {
                    onClose()
                    dismiss()
                }
            )
        }
        .onAppear {
            if let p = prefill, selectedFood?.id != p.id {
                // onAppear is already on main thread
                selectedFood = p
                searchQuery = p.name
                NSLog("📝 [FoodLogger] prefilledFoodView.onAppear set prefill as selectedFood: '\(p.name)'")
            }
        }
    }

    // MARK: Popular Foods

    private var popularFoodsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Popular Foods")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    ForEach(PopularFoods.foods) { food in
                        PopularFoodCard(food: food) {
                            selectedFood = food
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: Search Results

    private var searchResultsSection: some View {
        ScrollView {
            VStack(spacing: 12) {
                if searchResults.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(Color(hex: "#9CA3AF"))
                        Text("No foods found")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "#1A2332"))
                        Text("Try searching for \"\(searchQuery)\" with different keywords")
                            .font(.system(size: 14))
                            .foregroundColor(Color(hex: "#6B7280"))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .padding(.top, 40)
                } else {
                    ForEach(searchResults.prefix(20), id: \.id) { item in
                        Button {
                            // User explicitly chooses a result → this overrides PREFILL
                            selectedFood = item.toFoodItem()
                        } label: {
                            LocalFoodRow(food: item)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }

    // MARK: Initial Portion (edit mode)

    private var initialPortion: Double {
        guard let editId = editId,
              let loggedMeal = loggedMeals.first(where: { $0.id == editId }) else {
            return 1.0
        }
        return loggedMeal.portion
    }
}

// MARK: - Popular Food Card

struct PopularFoodCard: View {
    let food: FoodItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                Text(getEmoji(for: food.name))
                    .font(.system(size: 36))
                    .frame(height: 40) // Fixed height for emoji

                Text(food.name)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundColor(Color(hex: "#1A2332"))
                    .frame(height: 32) // Fixed height for 2 lines of text
                    .minimumScaleFactor(0.8) // Allow slight scaling if needed

                Text("\(food.calories) cal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "#6B7280"))
                    .frame(height: 16) // Fixed height for calories
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120) // Fixed height for entire card
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 2)
                    )
            )
            .shadow(color: ForkiTheme.borderPrimary.opacity(0.08), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func getEmoji(for name: String) -> String {
        if name.contains("Burrito Bowl") {
            return "🥙"
        } else if name.contains("Turkey Sandwich") || name.contains("Sandwich") {
            return "🥪"
        } else if name.contains("Caesar Salad") || name.contains("Salad") {
            return "🥗"
        } else if name.contains("Pizza") {
            return "🍕"
        } else if name.contains("Hamburger") || name.contains("Burger") {
            return "🍔"
        } else if name.contains("Pasta") {
            return "🍝"
        } else if name.contains("Rice Bowl") || name.contains("Rice") {
            return "🍚"
        } else if name.contains("Oatmeal") || name.contains("Oat") {
            return "🥣"
        } else if name.contains("Yogurt") || name.contains("Parfait") {
            return "🍨"
        } else if name.contains("Smoothie") {
            return "🥤"
        } else if name.contains("Chicken Breast") || name.contains("Chicken") {
            return "🍗"
        } else if name.contains("Mac & Cheese") || name.contains("Mac") {
            return "🧀"
        }
        return "🍽"
    }
}

// MARK: - LocalFood Row

struct LocalFoodRow: View {
    let food: RapidSearch.LocalFood

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(food.name)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                    .lineLimit(2)

                if !food.category.isEmpty {
                    Text(food.category)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "#6B7280"))
                }
            }
            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if food.calories > 0 {
                    Text("\(Int(food.calories)) cal")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(ForkiTheme.borderPrimary)
                }

                HStack(spacing: 6) {
                    if food.protein > 0 {
                        Text("P: \(String(format: "%.1f", food.protein))g")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "#6B7280"))
                    }
                    if food.carbs > 0 {
                        Text("C: \(String(format: "%.1f", food.carbs))g")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "#6B7280"))
                    }
                    if food.fat > 0 {
                        Text("F: \(String(format: "%.1f", food.fat))g")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Color(hex: "#6B7280"))
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 2)
                )
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.08), radius: 6, x: 0, y: 2)
    }
}

// MARK: - Detail Panel

struct FoodDetailView: View {
    let food: FoodItem
    let onSave: (LoggedFood) -> Void
    let onCancel: () -> Void
    let isEditMode: Bool
    let editId: UUID?
    let initialPortion: Double
    let loggedMeals: [LoggedFood]
    
    @State private var portion: Double
    
    init(
        food: FoodItem,
        isEditMode: Bool = false,
        editId: UUID? = nil,
        initialPortion: Double = 1.0,
        loggedMeals: [LoggedFood] = [],
        onSave: @escaping (LoggedFood) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.food = food
        self.isEditMode = isEditMode
        self.editId = editId
        self.initialPortion = initialPortion
        self.loggedMeals = loggedMeals
        self.onSave = onSave
        self.onCancel = onCancel
        _portion = State(initialValue: initialPortion)
    }

    // Get original timestamp when editing
    private var originalTimestamp: Date {
        guard let editId = editId,
              let loggedMeal = loggedMeals.first(where: { $0.id == editId }) else {
            return Date()
        }
        return loggedMeal.timestamp
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Food Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Food")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                Text(food.name)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ForkiTheme.borderPrimary.opacity(0.3), lineWidth: 2)
                            )
                    )
            }
            .padding(.horizontal, 20)

            // Portion Size
            VStack(spacing: 12) {
                HStack {
                    Text("Portion Size")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A2332"))
                    Spacer()
                    Text("\(Int(portion * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(ForkiTheme.borderPrimary)
                }
                .padding(.horizontal, 20)
                Slider(value: $portion, in: 0.1...3.0, step: 0.1)
                    .tint(ForkiTheme.borderPrimary)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)

            // Nutrition Info
            // Note: food contains base values (for 1.0 portion)
            // portion starts at initialPortion (the original portion when logged)
            // Display shows: base values * current portion
            VStack(spacing: 16) {
                Text("Nutrition")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                
                VStack(spacing: 12) {
                    nutritionRow(label: "Calories", value: "\(Int(Double(food.calories) * portion))", isPrimary: true)
                    HStack(spacing: 16) {
                        nutritionRow(label: "Protein", value: String(format: "%.1f", food.protein * portion))
                        nutritionRow(label: "Carbs", value: String(format: "%.1f", food.carbs * portion))
                        nutritionRow(label: "Fats", value: String(format: "%.1f", food.fats * portion))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ForkiTheme.borderPrimary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("Cancel")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#6B7280"))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(Color.white)
                                .overlay(
                                    Capsule()
                                        .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 2)
                                )
                        )
                        .shadow(color: ForkiTheme.borderPrimary.opacity(0.08), radius: 6, x: 0, y: 2)
                }
                
                Button {
                    let adjustedFood = FoodItem(
                        id: food.id,
                        name: food.name,
                        calories: Int(Double(food.calories) * portion),
                        protein: food.protein * portion,
                        carbs: food.carbs * portion,
                        fats: food.fats * portion,
                        category: food.category,
                        usdaFood: food.usdaFood
                    )
                    
                    // In edit mode, preserve original ID and timestamp
                    let logged = LoggedFood(
                        id: editId ?? UUID(), // Preserve original ID when editing
                        food: adjustedFood,
                        portion: portion,
                        timestamp: isEditMode ? originalTimestamp : Date() // Preserve original timestamp when editing
                    )
                    onSave(logged)
                } label: {
                    Text(isEditMode ? "Edit Log" : "Log Food")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#8DD4D1"), Color(hex: "#6FB8B5")], // Mint gradient
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(Color(hex: "#7AB8B5"), lineWidth: 2) // 2px border
                                )
                        )
                        .shadow(color: ForkiTheme.actionShadow, radius: 12, x: 0, y: 6)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
    }
    
    private func nutritionRow(label: String, value: String, isPrimary: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: isPrimary ? 24 : 20, weight: .bold, design: .rounded))
                .foregroundColor(isPrimary ? ForkiTheme.borderPrimary : Color(hex: "#1A2332"))
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Manual Log Icon

struct ManualLogIcon: View {
    var body: some View {
        Image(systemName: "square.and.pencil")
            .font(.system(size: 18))
            .foregroundColor(ForkiTheme.borderPrimary)
    }
}

// MARK: - Manual Food Log View (unchanged)

struct ManualFoodLogView: View {
    let onSave: (LoggedFood) -> Void
    let onCancel: () -> Void

    @State private var foodName: String = ""
    @State private var category: String = ""
    @State private var portion: Double = 1.0
    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fats: String = ""

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            // Food Name
            VStack(alignment: .leading, spacing: 8) {
                Text("Food")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                TextField("Enter food name", text: $foodName)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ForkiTheme.borderPrimary.opacity(0.3), lineWidth: 2)
                            )
                    )
                    .foregroundColor(Color(hex: "#1A2332"))
            }
            .padding(.horizontal, 20)

            // Category
            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))
                TextField("Enter category", text: $category)
                    .textFieldStyle(PlainTextFieldStyle())
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(ForkiTheme.borderPrimary.opacity(0.3), lineWidth: 2)
                            )
                    )
                    .foregroundColor(Color(hex: "#1A2332"))
            }
            .padding(.horizontal, 20)

            // Portion Size
            VStack(spacing: 12) {
                HStack {
                    Text("Portion Size")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(Color(hex: "#1A2332"))
                    Spacer()
                    Text("\(Int(portion * 100))%")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(ForkiTheme.borderPrimary)
                }
                .padding(.horizontal, 20)
                Slider(value: $portion, in: 0.1...3.0, step: 0.1)
                    .tint(ForkiTheme.borderPrimary)
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 8)

            // Nutrition (per portion) - Editable fields
            VStack(spacing: 16) {
                Text("Nutrition (per portion)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(Color(hex: "#1A2332"))

                HStack(spacing: 16) {
                    editableNutrientColumn(title: "Calories", value: $calories, isPrimary: true)
                    editableNutrientColumn(title: "Protein", value: $protein)
                }

                HStack(spacing: 16) {
                    editableNutrientColumn(title: "Carbs", value: $carbs)
                    editableNutrientColumn(title: "Fats", value: $fats)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ForkiTheme.borderPrimary.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 2)
                    )
            )
            .padding(.horizontal, 20)

            // Log Food button
            Button {
                let caloriesValue = Int(calories) ?? 0
                let proteinValue = Double(protein) ?? 0.0
                let carbsValue = Double(carbs) ?? 0.0
                let fatsValue = Double(fats) ?? 0.0

                let logged = LoggedFood(
                    food: FoodItem(
                        id: Int.random(in: 1000...9999),
                        name: foodName.isEmpty ? "Manual Entry" : foodName,
                        calories: Int(Double(caloriesValue) * portion),
                        protein: proteinValue * portion,
                        carbs: carbsValue * portion,
                        fats: fatsValue * portion,
                        category: category.isEmpty ? "Manual" : category
                    ),
                    portion: portion,
                    timestamp: Date()
                )
                onSave(logged)
            } label: {
                Text("Log Food")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#8DD4D1"), Color(hex: "#6FB8B5")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                Capsule()
                                    .stroke(Color(hex: "#7AB8B5"), lineWidth: 2)
                            )
                    )
                    .shadow(color: ForkiTheme.actionShadow, radius: 12, x: 0, y: 6)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 2)
                )
        )
        .shadow(color: ForkiTheme.borderPrimary.opacity(0.15), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }

    private func editableNutrientColumn(title: String, value: Binding<String>, isPrimary: Bool = false) -> some View {
        VStack(spacing: 4) {
            TextField(isPrimary ? "0" : "0.0", text: value)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: isPrimary ? 24 : 20, weight: .bold, design: .rounded))
                .foregroundColor(isPrimary ? ForkiTheme.borderPrimary : Color(hex: "#1A2332"))
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white.opacity(0.8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(ForkiTheme.borderPrimary.opacity(0.2), lineWidth: 1.5)
                        )
                )
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(hex: "#6B7280"))
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview

#Preview("FoodLoggerView") {
    FoodLoggerView(
        prefill: nil,
        loggedMeals: [],
        onSave: { _ in },
        onClose: {},
        onDeleteFromHistory: { _ in }
    )
}

