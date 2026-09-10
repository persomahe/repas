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

    @State private var afficherInformations = false
    
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

    /// Ingrédients déjà ajoutés, issus de l'état persisté de la course.
    private var dejaAjoutes: [IngredientAgrege] {
        course.ingredients.compactMap { ingredient in
            guard let produit = ingredient.produit, ingredient.quantite > 0 else { return nil }
            return IngredientAgrege(
                id: produit.persistentModelID,
                produit: produit,
                quantite: ingredient.quantite
            )
        }
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
                    .frame(width: geometry.size.width * 1.4, height: 280)
                    .offset(x: -geometry.size.width * 0.2, y: -36)
            }
            .ignoresSafeArea()

            List {
                Section {
                    SectionHeader(title: "Déjà ajoutés", systemImage: "checkmark.circle")

                    if dejaAjoutes.isEmpty {
                        Text("Aucun ingrédient déjà ajouté.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 70), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(dejaAjoutes) { ingredient in
                                Button {
                                    retirerDuPanier(ingredient.produit)
                                } label: {
                                    IngredientCard(
                                        nom: ingredient.produit.nom,
                                        quantite: ingredient.quantite
                                    )
                                }
                                .buttonStyle(.plain)
                                .transition(.slide)
                                .scaleEffect(carteAnimee == ingredient.id ? 1.2 : 1.0)
                                .animation(
                                    .spring(response: 0.4, dampingFraction: 0.65),
                                    value: carteAnimee
                                )
                            }
                        }
                    }
                }

                Section {
                    HStack {
                        SectionHeader(title: "À prendre", systemImage: "plus.circle")
                        Spacer()

                        Menu {
                            Button {
                                tagSelectionne = nil
                            } label: {
                                Label(
                                    "Tous les produits",
                                    systemImage: tagSelectionne == nil
                                        ? "checkmark"
                                        : "line.3.horizontal.decrease.circle"
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
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 70), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(produitsFiltres) { produit in
                                Button {
                                    ajouterAprendre(produit)
                                } label: {
                                    IngredientCard(nom: produit.nom, quantite: produit.typeUnite.pas)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(.clear)
        }
        .task {
            course.materialiserIngredientsHerites()
            course.ingredients.forEach { $0.mettreAJourQuantite() }
            try? modelContext.save()
        }
        .navigationTitle("Liste de courses")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    afficherInformations = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("Afficher les informations")
            }
        }
        .sheet(isPresented: $afficherInformations) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        let texte = AttributedString("""
                        - Les ingrédients « Déjà ajoutés » sont ceux hérités automatiquement des recettes pour cette semaine.
                        - Les ingrédients « À prendre » sont tous les produits existants, filtrables par tag (menu bleu).
                        """)

                        Text(texte)

                        Text("Fonctionnement général")
                            .font(.headline)

                        let details = AttributedString("""
                        - Pour ajouter un ingrédient à la liste de courses, clique directement sur un produit (le carré) dans la section « À prendre » :
                        1 clic = ajoute 1 unité, 2 clics = ajoute 2 unités, etc ;
                        1 unité = 1 produit ou 100 gr de produit.
                        - Pour retirer un ingrédient de la liste de courses, clique directement sur un produit (le carré) dans la section « Déjà ajoutés » :
                        1 clic = retire 1 unité, 2 clics = retire 2 unités, etc ;
                        1 unité = 1 produit ou 100 gr de produit.
                        """)
                        Text(details)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .navigationTitle("Informations")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") {
                            afficherInformations = false
                        }
                    }
                }
                .tint(.green)
            }
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
                ingredientExistant.quantiteManuelle += produit.typeUnite.pas
                ingredientExistant.mettreAJourQuantite()
            } else {
                let nouvelIngredient = IngredientCourse(
                    course: course,
                    produit: produit,
                    quantite: produit.typeUnite.pas,
                    quantiteManuelle: produit.typeUnite.pas
                )
                modelContext.insert(nouvelIngredient)
                course.ingredients.append(nouvelIngredient)
            }
            try? modelContext.save()

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

    /// Retire une unité, d'abord héritée des recettes, puis ajoutée manuellement.
    private func retirerDuPanier(_ produit: Produit) {
        guard course.modelContext != nil else {
            assertionFailure("Impossible de retirer: la Course n'est pas attachée au ModelContext")
            return
        }

        guard let ingredient = course.ingredients.first(where: { $0.produit === produit }) else {
            return
        }

        let id = produit.persistentModelID
        let pas = produit.typeUnite.pas
        carteAnimee = id

        if ingredient.quantiteHeriteeRestante > 0 {
            ingredient.quantiteHeriteeRestante = max(0, ingredient.quantiteHeriteeRestante - pas)
        } else {
            ingredient.quantiteManuelle = max(0, ingredient.quantiteManuelle - pas)
        }
        ingredient.mettreAJourQuantite()
        try? modelContext.save()

        if ingredient.quantite > 0 {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                // La quantité est déjà persistée et recalculée ci-dessus.
            }
        } else {
            // Laisse le zoom être visible avant de retirer la dernière unité.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard course.ingredients.contains(where: { $0.persistentModelID == ingredient.persistentModelID }) else {
                    reinitialiserAnimationCarte(id: id)
                    return
                }

                withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
                    modelContext.delete(ingredient)
                    course.ingredients.removeAll { $0.persistentModelID == ingredient.persistentModelID }
                }
                try? modelContext.save()
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
