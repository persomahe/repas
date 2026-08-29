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

    /// Tous les produits existants, pour la liste "à prendre"
    @Query(sort: \Produit.nom) private var produits: [Produit]

    /// Ingrédients "à prendre" saisis par l'utilisateur (non encore enregistrés dans la course)
    @State private var aPrendre: [IngredientCourse] = []

    /// Ingrédients déjà ajoutés, fusionnés par produit
    private var dejaAjoutes: [IngredientCourse] {
        var fusion: [Produit: Double] = [:]
        for ingredient in course.ingredients {
            guard let produit = ingredient.produit else { continue }
            fusion[produit, default: 0] += ingredient.quantite
        }
        return fusion.map { IngredientCourse(produit: $0.key, quantite: $0.value) }
            .sorted { ($0.produit?.nom ?? "") < ($1.produit?.nom ?? "") }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Date de la course
                Label(course.date.formatted(date: .complete, time: .omitted), systemImage: "cart")
                    .font(.headline)

                // Section "Déjà ajoutés"
                SectionHeader(title: "Déjà ajoutés", systemImage: "checkmark.circle.fill")
                if dejaAjoutes.isEmpty {
                    Text("Aucun ingrédient ajouté pour l'instant.")
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                        ForEach(dejaAjoutes) { ingredient in
                            IngredientCard(
                                nom: ingredient.produit?.nom ?? "Inconnu",
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
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
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
            .padding()
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
        for ingredient in aPrendre {
            course.ingredients.append(ingredient)
        }
        aPrendre = []
    }
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
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(quantite.formatted(.number.precision(.fractionLength(0...2))))
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.tint)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
}

#Preview {
    NavigationStack {
        CourseListView(course: Course(date: .now))
    }
    .modelContainer(for: [Tag.self, Produit.self, Recette.self, IngredientRecette.self, Semaine.self, RecetteSemaine.self, Course.self, IngredientCourse.self], inMemory: true)
}
