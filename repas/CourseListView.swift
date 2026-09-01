//
//  CourseListView.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

/// Écran affichant la liste de courses : ingrédients déjà ajoutés et ingrédients à prendre.
struct CourseListView: View {
    /// La course affichée
    let course: Course

    @Environment(\.modelContext) private var modelContext

    /// Tous les produits existants, pour la liste "à prendre"
    @Query(sort: \Produit.nom) private var produits: [Produit]

    /// Ingrédients "à prendre" saisis par l'utilisateur (non encore enregistrés dans la course)
    @State private var aPrendre: [IngredientCourse] = []

    /// Ingrédients déjà ajoutés, fusionnés par produit
    private var dejaAjoutes: [IngredientAgrege] {
        guard course.modelContext != nil else {
            assertionFailure("CourseListView reçoit une Course non attachée au ModelContext")
            return []
        }

        var fusion: [PersistentIdentifier: IngredientAgrege] = [:]

        func ajouter(_ produit: Produit, quantite: Double) {
            let id = produit.persistentModelID
            if var element = fusion[id] {
                element.quantite += quantite
                fusion[id] = element
            } else {
                fusion[id] = IngredientAgrege(id: id, produit: produit, quantite: quantite)
            }
        }

        // 1. Ingrédients déjà enregistrés dans la course
        for ingredient in course.ingredients {
            guard let produit = ingredient.produit else { continue }
            ajouter(produit, quantite: ingredient.quantite)
        }

        // 2. Ingrédients calculés à partir des recettes de la semaine
        if let semaine = course.semaine {
            for planification in semaine.recettes {
                guard let recette = planification.recette,
                      recette.nombreDeParts > 0 else { continue }

                let ratio = Double(planification.nombreDeParts) / Double(recette.nombreDeParts)

                for ingredient in recette.ingredients {
                    guard let produit = ingredient.produit else { continue }
                    ajouter(produit, quantite: ingredient.quantite * ratio)
                }
            }
        }

        return Array(fusion.values)
            .sorted { $0.produit.nom < $1.produit.nom }
    }

    var body: some View {
        List {
            // Section "Déjà ajoutés"
            SectionHeader(title: "Déjà ajoutés", systemImage: "checkmark.circle")
            if dejaAjoutes.isEmpty {
                Text("Aucun ingrédient déjà ajouté.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 70), spacing: 12)], spacing: 12) {
                    ForEach(dejaAjoutes) { ingredient in
                        IngredientCard(
                            nom: ingredient.produit.nom,
                            quantite: ingredient.quantite
                        )
                    }
                }
            }

            // Section "À prendre"
            SectionHeader(title: "À prendre", systemImage: "plus.circle")
            if produits.isEmpty {
                Text("Aucun produit disponible. Crée d'abord des produits.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 12)], spacing: 12) {
                    ForEach(produits) { produit in
                        Button {
                            ajouterAprendre(produit)
                        } label: {
                            IngredientCard(
                                nom: produit.nom,
                                quantite: quantitePour(produit)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !aPrendre.isEmpty {
                Button("Ajouter à la course", systemImage: "cart.badge.plus") {
                    enregistrerAprendre()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
        }

        .navigationTitle("Liste de courses")
    }

    /// Quantité affichée pour un produit "à prendre" (1 par défaut, doublée à chaque clic).
    private func quantitePour(_ produit: Produit) -> Double {
        aPrendre.first { $0.produit === produit }?.quantite ?? 1
    }

    /// Clic sur un produit "à prendre" : double la quantité s'il est déjà présent, sinon l'ajoute avec qté 1.
    private func ajouterAprendre(_ produit: Produit) {
        if let index = aPrendre.firstIndex(where: { $0.produit === produit }) {
            aPrendre[index].quantite *= 2
        } else {
            aPrendre.append(IngredientCourse(produit: produit, quantite: 1))
        }
    }

    /// Enregistre les ingrédients "à prendre" dans la course puis vide la liste.
    private func enregistrerAprendre() {
        guard course.modelContext != nil else {
            assertionFailure("Impossible d'enregistrer: la Course n'est pas attachée au ModelContext")
            return
        }

        for ingredient in aPrendre {
            modelContext.insert(ingredient)
            course.ingredients.append(ingredient)
        }
        aPrendre = []
    }
}

/// Représentation agrégée d'un produit dans la liste de courses.
private struct IngredientAgrege: Identifiable {
    let id: PersistentIdentifier
    let produit: Produit
    var quantite: Double
}

/// En-tête de section avec icône.
private struct SectionHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.headline)
            .foregroundStyle(.secondary)
    }
}

/// Carte (carré) affichant le nom d'un ingrédient et sa quantité.
private struct IngredientCard: View {
    let nom: String
    let quantite: Double

    var body: some View {
        VStack(spacing: 6) {
            Text(nom)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(quantite.formatted(.number.precision(.fractionLength(0...2))))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.purple)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        PreviewCourseView()
    }
    .modelContainer(PreviewData.container())
}
