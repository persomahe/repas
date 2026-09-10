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
    let container: ModelContainer

    init() {
        do {
            let schema = Schema([
                Tag.self,
                Produit.self,
                Recette.self,
                IngredientRecette.self,
                Semaine.self,
                RecetteSemaine.self,
                Course.self,
                IngredientCourse.self
            ])

            let container = try ModelContainer(for: schema)
            self.container = container

            try InitialDataImporter.importerSiNecessaire(
                dans: container.mainContext
            )
        } catch {
            fatalError("Impossible d'initialiser la base de données : \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
