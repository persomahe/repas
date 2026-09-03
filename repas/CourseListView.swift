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

    /// Tags disponibles pour filtrer les produits.
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]

    /// Tag sélectionné pour la section « À prendre ».
    @State private var tagSelectionne: Tag?
    @State private var carteAnimee: PersistentIdentifier?

    private var produitsFiltres: [Produit] {
        guard let tagSelectionne else { return produits }
        return produits.filter { produit in
            produit.tags.contains { tag in
                tag.persistentModelID == tagSelectionne.persistentModelID
            }
        }
    }

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
        ZStack(alignment: .top) {
            Color(hex: "#FEF6E7")
                .ignoresSafeArea()

            GeometryReader { geometry in
                Ellipse()
                    .fill(
                        LinearGradient(
                            colors: [.green, .mint],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(
                        width: geometry.size.width * 1.4,
                        height: 280
                    )
                    .offset(
                        x: -geometry.size.width * 0.2,
                        y: -36
                    )
            }
            .ignoresSafeArea()
            List {
            // Section "Déjà ajoutés"
            SectionHeader(title: "Déjà ajoutés", systemImage: "checkmark.circle")
            if dejaAjoutes.isEmpty {
                Text("Aucun ingrédient déjà ajouté.")
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 70), spacing: 12)], spacing: 12) {
                    ForEach(dejaAjoutes, id: \.id) { ingredient in
                        Button {
                            retirerDuPanier(ingredient.produit)
                        } label: {
                            IngredientCard(
                                nom: ingredient.produit.nom,
                                quantite: ingredient.quantite
                            )
                            .scaleEffect(carteAnimee == ingredient.id ? 1.2 : 1)
                            .animation(
                                .spring(response: 0.35, dampingFraction: 0.55),
                                value: carteAnimee == ingredient.id
                            )
                        }
                        .buttonStyle(.plain)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.2).combined(with: .opacity),
                                removal: .opacity
                            )
                        )
                    }
                }
                .animation(
                    .spring(response: 0.45, dampingFraction: 0.6),
                    value: dejaAjoutes.map(\.id)
                )

            }

            // Section "À prendre"
            HStack {
                SectionHeader(title: "À prendre", systemImage: "plus.circle")

                Spacer()

                Menu {
                    Button {
                        tagSelectionne = nil
                    } label: {
                        Label(
                            "Tous les produits",
                            systemImage: tagSelectionne == nil ? "checkmark" : "line.3.horizontal.decrease.circle"
                        )
                    }

                    ForEach(tousLesTags) { tag in
                        Button {
                            tagSelectionne = tag
                        } label: {
                            Label(
                                tag.nom,
                                systemImage: tagSelectionne?.persistentModelID == tag.persistentModelID
                                    ? "checkmark"
                                    : "tag"
                            )
                        }
                    }
                } label: {
                    Label(
                        tagSelectionne?.nom ?? "Tous",
                        systemImage: tagSelectionne == nil
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill"
                    )
                    .font(.caption)
                }
            }
            .padding(.vertical, 4)

            if produitsFiltres.isEmpty {
                Text(
                    produits.isEmpty
                    ? "Aucun produit disponible. Crée d'abord des produits."
                    : "Aucun produit avec ce tag."
                )
                .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 12)], spacing: 12) {
                    ForEach(produitsFiltres) { produit in
                        Button {
                            ajouterAprendre(produit)
                        } label: {
                            IngredientCard(
                                nom: produit.nom,
                                quantite: 1
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(.clear)
        .task {
            guard tagSelectionne == nil else { return }
            tagSelectionne = tousLesTags.first { tag in
                tag.nom.compare("Récurrent", options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
            }
        }
        .navigationTitle("Liste de courses")
        }
    }

    /// Clic sur un produit : ajoute immédiatement 1 unité à la course.
    private func ajouterAprendre(_ produit: Produit) {
        guard course.modelContext != nil else {
            assertionFailure("Impossible d'ajouter: la Course n'est pas attachée au ModelContext")
            return
        }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            if let ingredientExistant = course.ingredients.first(where: { $0.produit === produit }) {
                ingredientExistant.quantite += 1
            } else {
                let nouvelIngredient = IngredientCourse(
                    course: course,
                    produit: produit,
                    quantite: 1
                )
                modelContext.insert(nouvelIngredient)
                course.ingredients.append(nouvelIngredient)
            }

            let id = produit.persistentModelID
            DispatchQueue.main.async {
                carteAnimee = id
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    if carteAnimee == id {
                        carteAnimee = nil
                    }
                }
            }
        }
    }

    /// Retire une unité du produit cliqué et supprime sa ligne à zéro.
    private func retirerDuPanier(_ produit: Produit) {
        guard course.modelContext != nil else {
            assertionFailure("Impossible de retirer: la Course n'est pas attachée au ModelContext")
            return
        }

        guard let ingredient = course.ingredients.first(where: { $0.produit === produit }) else {
            return
        }

        let id = produit.persistentModelID
        carteAnimee = id

        if ingredient.quantite > 1 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                ingredient.quantite -= 1
            }

            reinitialiserAnimationCarte(id: id)
        } else {
            // Laisse le zoom être visible avant de retirer la dernière unité.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard course.ingredients.contains(where: { $0.produit === produit }) else {
                    reinitialiserAnimationCarte(id: id)
                    return
                }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    modelContext.delete(ingredient)
                    course.ingredients.removeAll { $0.persistentModelID == ingredient.persistentModelID }
                }
                reinitialiserAnimationCarte(id: id)
            }
        }
    }

    private func reinitialiserAnimationCarte(id: PersistentIdentifier) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
            if carteAnimee == id {
                carteAnimee = nil
            }
        }
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
            .foregroundStyle(.green)
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
                .fontWeight(.semibold)
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, minHeight: 70)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#34C759"))
        )
    }
}

#Preview {
    NavigationStack {
        PreviewCourseView()
    }
    .modelContainer(PreviewData.container())
}
