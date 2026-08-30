//
//  ContentView.swift
//  repas
//
//  Created by celine mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    /// Toutes les semaines, triées de la plus récente à la plus ancienne
    @Query(sort: \Semaine.date, order: .reverse) private var semaines: [Semaine]

    /// La dernière semaine (la plus récente), si elle existe
    private var derniereSemaine: Semaine? {
        semaines.first
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Application REPAS")

                NavigationLink("Voir les tags") {
                    TagListView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)

                NavigationLink("Voir les produits") {
                    ProduitListView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Voir les recettes") {
                    RecetteListView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Planifier ma semaine") {
                    SemaineListView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Ma liste de courses") {
                    if let semaine = derniereSemaine {
                        CourseListView(course: Course(semaine: semaine))
                    } else {
                        Text("Aucune semaine planifiée.")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("REPAS")
        }
    }
}

#Preview {
    ContentView()
}

// CourseListView(course: Course(semaine: .modelContainer(for: [Tag.self, Produit.self, Recette.self, IngredientRecette.self, Semaine.self, RecetteSemaine.self, Course.self, IngredientCourse.self])))
