//
//  RecetteListView.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

/// Écran affichant la liste des recettes enregistrées dans la base.
struct RecetteListView: View {
    /// Récupère automatiquement toutes les recettes, triées par nom
    @Query(sort: \Recette.nom) private var recettes: [Recette]

    /// Contrôle l'affichage de la fiche de création d'une recette
    @State private var ajoutEnCours = false

    var body: some View {
        List(recettes) { recette in
            VStack(alignment: .leading, spacing: 4) {
                Text(recette.nom)
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(recette.nombreDeParts) parts", systemImage: "person.2")
                    Label("\(recette.tempsPreparationMinutes) min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !recette.saisons.isEmpty {
                    Text(recette.saisons.map(\.rawValue).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !recette.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(recette.tags) { tag in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: tag.couleurHex))
                                    .frame(width: 8, height: 8)
                                Text(tag.nom)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Recettes")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Ajouter une recette", systemImage: "plus") {
                    ajoutEnCours = true
                }
            }
        }
        .sheet(isPresented: $ajoutEnCours) {
            NouvelleRecetteView()
        }
        .overlay {
            if recettes.isEmpty {
                ContentUnavailableView(
                    "Aucune recette",
                    systemImage: "book",
                    description: Text("Les recettes que tu créeras apparaîtront ici.")
                )
            }
        }
    }
}

/// Fiche de création d'une nouvelle recette.
struct NouvelleRecetteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Tags et produits existants, pour les sélections
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]
    @Query(sort: \Produit.nom) private var tousLesProduits: [Produit]

    @State private var nom = ""
    @State private var nombreDeParts = 4
    @State private var saisonsChoisies: Set<Saison> = []
    @State private var tagsChoisis: Set<Tag> = []
    @State private var lienTexte = ""
    @State private var tempsPreparationMinutes = 30

    /// Ingrédients en cours de composition : produit et quantité
    @State private var ingredients: [(produit: Produit, quantite: Double)] = []

    /// Saisie de l'ingrédient à ajouter
    @State private var produitChoisi: Produit?
    @State private var quantiteChoisie = 1.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de la recette", text: $nom)
                    Stepper("Parts : \(nombreDeParts)", value: $nombreDeParts, in: 1...50)
                    Stepper("Préparation : \(tempsPreparationMinutes) min", value: $tempsPreparationMinutes, in: 0...600, step: 5)
                }

                Section("Saisons") {
                    ForEach(Saison.allCases) { saison in
                        HStack {
                            Text(saison.rawValue)
                            Spacer()
                            if saisonsChoisies.contains(saison) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if saisonsChoisies.contains(saison) {
                                saisonsChoisies.remove(saison)
                            } else {
                                saisonsChoisies.insert(saison)
                            }
                        }
                    }
                }

                Section("Tags") {
                    if tousLesTags.isEmpty {
                        Text("Aucun tag disponible.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(tousLesTags) { tag in
                            HStack {
                                Circle()
                                    .fill(Color(hex: tag.couleurHex))
                                    .frame(width: 12, height: 12)
                                Text(tag.nom)
                                Spacer()
                                if tagsChoisis.contains(tag) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if tagsChoisis.contains(tag) {
                                    tagsChoisis.remove(tag)
                                } else {
                                    tagsChoisis.insert(tag)
                                }
                            }
                        }
                    }
                }

                Section("Lien vers la recette") {
                    TextField("URL ou chemin de fichier", text: $lienTexte)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Ingrédients") {
                    ForEach(ingredients.indices, id: \.self) { index in
                        HStack {
                            Text(ingredients[index].produit.nom)
                            Spacer()
                            Text(ingredients[index].quantite.formatted())
                                .foregroundStyle(.secondary)
                        }
                    }
                    .onDelete { indices in
                        ingredients.remove(atOffsets: indices)
                    }

                    if tousLesProduits.isEmpty {
                        Text("Aucun produit disponible. Crée d'abord des produits.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Produit", selection: $produitChoisi) {
                            Text("Choisir…").tag(Produit?.none)
                            ForEach(tousLesProduits) { produit in
                                Text(produit.nom).tag(Optional(produit))
                            }
                        }

                        HStack {
                            Text("Quantité")
                            Spacer()
                            TextField("Quantité", value: $quantiteChoisie, format: .number)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }

                        Button("Ajouter l'ingrédient", systemImage: "plus.circle") {
                            if let produit = produitChoisi {
                                ingredients.append((produit: produit, quantite: quantiteChoisie))
                                produitChoisi = nil
                                quantiteChoisie = 1.0
                            }
                        }
                        .disabled(produitChoisi == nil)
                    }
                }
            }
            .navigationTitle("Nouvelle recette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter", action: ajouterRecette)
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    /// Enregistre la recette et ses ingrédients, puis ferme la fiche.
    private func ajouterRecette() {
        let nomNettoye = nom.trimmingCharacters(in: .whitespaces)
        guard !nomNettoye.isEmpty else { return }

        let lienNettoye = lienTexte.trimmingCharacters(in: .whitespaces)

        let recette = Recette(
            nom: nomNettoye,
            nombreDeParts: nombreDeParts,
            saisons: Array(saisonsChoisies),
            tags: Array(tagsChoisis),
            lien: lienNettoye.isEmpty ? nil : URL(string: lienNettoye),
            tempsPreparationMinutes: tempsPreparationMinutes,
            ingredients: ingredients.map { IngredientRecette(produit: $0.produit, quantite: $0.quantite) }
        )
        context.insert(recette)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RecetteListView()
    }
    .modelContainer(for: [Tag.self, Produit.self, Recette.self, IngredientRecette.self], inMemory: true)
}
