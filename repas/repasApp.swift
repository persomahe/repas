//
//  repasApp.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

@main
struct repasApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Tag.self, Produit.self, Recette.self, Ingredient.self, IngredientRecette.self, Semaine.self, RecetteSemaine.self, Course.self, IngredientCourse.self])
    }
}
