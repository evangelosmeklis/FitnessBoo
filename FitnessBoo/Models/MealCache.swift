//
//  MealCache.swift
//  FitnessBoo
//
//  Created by Claude on 23/9/25.
//

import Foundation

struct CachedMeal: Codable, Identifiable, Hashable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double?
    let lastUsed: Date

    init(name: String, calories: Double, protein: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.calories = calories
        self.protein = protein
        self.lastUsed = Date()
    }

    init(id: UUID, name: String, calories: Double, protein: Double?, lastUsed: Date) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.lastUsed = lastUsed
    }

    func updatedWithCurrentTime() -> CachedMeal {
        return CachedMeal(
            id: self.id,
            name: self.name,
            calories: self.calories,
            protein: self.protein,
            lastUsed: Date()
        )
    }
}

class MealCacheService: ObservableObject {
    private let maxCacheSize = 50
    private let cacheKey = "CachedMeals"

    @Published private(set) var cachedMeals: [CachedMeal] = []

    init() {
        loadCachedMeals()
    }

    func addMeal(name: String, calories: Double, protein: Double?) {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        // Check if meal already exists
        if let existingIndex = cachedMeals.firstIndex(where: { $0.name.lowercased() == trimmedName.lowercased() }) {
            // Update existing meal with new values and current timestamp
            let existingMeal = cachedMeals[existingIndex]
            let updatedMeal = CachedMeal(
                id: existingMeal.id,
                name: trimmedName,
                calories: calories,
                protein: protein,
                lastUsed: Date()
            )
            cachedMeals[existingIndex] = updatedMeal
        } else {
            // Add new meal
            let newMeal = CachedMeal(name: trimmedName, calories: calories, protein: protein)
            cachedMeals.insert(newMeal, at: 0)
        }

        // Maintain cache size (LRU)
        maintainCacheSize()
        saveCachedMeals()
    }

    func useMeal(_ meal: CachedMeal) -> CachedMeal {
        // Move meal to front and update timestamp
        if let index = cachedMeals.firstIndex(where: { $0.id == meal.id }) {
            let updatedMeal = meal.updatedWithCurrentTime()
            cachedMeals.remove(at: index)
            cachedMeals.insert(updatedMeal, at: 0)
            saveCachedMeals()
            return updatedMeal
        }
        return meal
    }

    func searchMeals(query: String) -> [CachedMeal] {
        guard !query.isEmpty else { return cachedMeals }

        let lowercaseQuery = query.lowercased()
        return cachedMeals.filter { meal in
            meal.name.lowercased().contains(lowercaseQuery)
        }
    }

    private func maintainCacheSize() {
        if cachedMeals.count > maxCacheSize {
            // Sort by lastUsed (most recent first) and keep only the top 50
            cachedMeals.sort { $0.lastUsed > $1.lastUsed }
            cachedMeals = Array(cachedMeals.prefix(maxCacheSize))
        }
    }

    private func loadCachedMeals() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let meals = try? JSONDecoder().decode([CachedMeal].self, from: data) else {
            cachedMeals = []
            return
        }

        // Sort by lastUsed (most recent first)
        cachedMeals = meals.sorted { $0.lastUsed > $1.lastUsed }
    }

    private func saveCachedMeals() {
        guard let data = try? JSONEncoder().encode(cachedMeals) else { return }
        UserDefaults.standard.set(data, forKey: cacheKey)
    }

    func clearCache() {
        cachedMeals.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}