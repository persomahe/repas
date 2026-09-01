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
    @Environment(\.modelContext) private var context

    /// Récupère automatiquement toutes les recettes, triées par nom
    @Query(sort: \Recette.nom) private var recettes: [Recette]

    /// Contrôle l'affichage de la fiche de création d'une recette
    @State private var ajoutEnCours = false

    /// Recette sélectionnée pour consultation / modification.
    @State private var recetteAEditer: Recette?

    /// Recette sélectionnée pour suppression (avec confirmation).
    @State private var recetteASupprimer: Recette?

    var body: some View {
        List {
            ForEach(recettes.indices, id: \.self) { index in
                recetteRow(recettes[index])
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
        .sheet(item: $recetteAEditer) { recette in
            EditRecetteView(recette: recette)
        }
        .confirmationDialog(
            "Supprimer cette recette ?",
            isPresented: suppressionDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let recetteASupprimer {
                    context.delete(recetteASupprimer)
                }
                recetteASupprimer = nil
            }
            Button("Annuler", role: .cancel) {
                recetteASupprimer = nil
            }
        } message: {
            Text(suppressionMessage)
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

    @ViewBuilder
    private func recetteRow(_ recette: Recette) -> some View {
        HStack {
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

            Spacer()

            Button {
                recetteAEditer = recette
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modifier la recette \(recette.nom)")

            Button {
                recetteASupprimer = recette
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.red)
            .accessibilityLabel(Text("Supprimer la recette"))
        }
    }

    private var suppressionDialogBinding: Binding<Bool> {
        Binding(
            get: { recetteASupprimer != nil },
            set: { if !$0 { recetteASupprimer = nil } }
        )
    }

    private var suppressionMessage: String {
        guard let nom = recetteASupprimer?.nom, !nom.isEmpty else {
            return "Cette recette sera supprimee definitivement."
        }
        return "La recette \(nom) sera supprimee definitivement."
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

/// Fiche de consultation / modification d'une recette existante.
struct EditRecetteView: View {
    let recette: Recette

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Tags et produits existants, pour les sélections
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]
    @Query(sort: \Produit.nom) private var tousLesProduits: [Produit]

    @State private var nom: String
    @State private var nombreDeParts: Int
    @State private var saisonsChoisies: Set<Saison>
    @State private var tagsChoisis: Set<Tag>
    @State private var lienTexte: String
    @State private var tempsPreparationMinutes: Int

    /// Ingrédients en cours de composition : produit et quantité
    @State private var ingredients: [(produit: Produit, quantite: Double)]

    /// Saisie de l'ingrédient à ajouter
    @State private var produitChoisi: Produit?
    @State private var quantiteChoisie = 1.0

    init(recette: Recette) {
        self.recette = recette
        _nom = State(initialValue: recette.nom)
        _nombreDeParts = State(initialValue: recette.nombreDeParts)
        _saisonsChoisies = State(initialValue: Set(recette.saisons))
        _tagsChoisis = State(initialValue: Set(recette.tags))
        _lienTexte = State(initialValue: recette.lien?.absoluteString ?? "")
        _tempsPreparationMinutes = State(initialValue: recette.tempsPreparationMinutes)
        _ingredients = State(initialValue: recette.ingredients.map { (produit: $0.produit!, quantite: $0.quantite) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de la recette", text: $nom)
                        .fontWeight(.semibold)
                    HStack {
                        Text("Parts")

                        Button {
                            nombreDeParts = max(1, nombreDeParts - 1)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)

                        Text("\(nombreDeParts)")
                            .monospacedDigit()
                            .frame(width: 20)

                        Button {
                            nombreDeParts = min(50, nombreDeParts + 1)
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Text("Préparation (min)")


                         Button {
                             tempsPreparationMinutes = max(0, tempsPreparationMinutes - 5)
                         } label: {
                             Image(systemName: "minus.circle")
                         }
                         .buttonStyle(.borderless)

                         Text("\(tempsPreparationMinutes)")
                             .monospacedDigit()
                             .frame(width: 30)

                         Button {
                             tempsPreparationMinutes = min(600, tempsPreparationMinutes + 5)
                         } label: {
                             Image(systemName: "plus.circle")
                         }
                         .buttonStyle(.borderless)
                    }
                }

                Section("Ingrédients") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 70), spacing: 12)
                        ]                    ) {
                        ForEach(ingredients.indices, id: \.self) { index in
                            VStack(spacing: 6) {
                                Text(ingredients[index].produit.nom)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                Text(ingredients[index].quantite.formatted())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
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
                    .padding(.vertical, 8)

                    if tousLesProduits.isEmpty {
                        Text("Aucun produit disponible. Crée d'abord des produits.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Ingrédient à ajouter", selection: $produitChoisi) {
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
 
                
                Section("Lien vers la recette") {
                    TextField("URL ou chemin de fichier", text: $lienTexte)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("Saisons") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 70), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(Saison.allCases) { saison in
                            let saisonSelectionnee = saisonsChoisies.contains(saison)

                            Button {
                                if saisonSelectionnee {
                                    saisonsChoisies.remove(saison)
                                } else {
                                    saisonsChoisies.insert(saison)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: saisonSelectionnee ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(saisonSelectionnee ? Color.accentColor : Color.secondary)

                                    Text(saison.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            saisonSelectionnee
                                            ? Color.accentColor.opacity(0.15)
                                            : Color(.secondarySystemBackground)
                                        )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            saisonSelectionnee
                                            ? Color.accentColor
                                            : Color.clear,
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
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

 

            }
            .navigationTitle("Modifier la recette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: enregistrerRecette)
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .font(.subheadline)

        }
    }

    /// Enregistre les modifications de la recette, puis ferme la fiche.
    private func enregistrerRecette() {
        let nomNettoye = nom.trimmingCharacters(in: .whitespaces)
        guard !nomNettoye.isEmpty else { return }

        let lienNettoye = lienTexte.trimmingCharacters(in: .whitespaces)

        recette.nom = nomNettoye
        recette.nombreDeParts = nombreDeParts
        recette.saisons = Array(saisonsChoisies)
        recette.tags = Array(tagsChoisis)
        recette.lien = lienNettoye.isEmpty ? nil : URL(string: lienNettoye)
        recette.tempsPreparationMinutes = tempsPreparationMinutes
        recette.ingredients = ingredients.map { ingredient in
            IngredientRecette(
                produit: ingredient.produit,
                quantite: ingredient.quantite
            )
        }
        dismiss()
    }
}

#Preview("Liste des recettes") {
    NavigationStack {
        RecetteListView()
    }
    .modelContainer(PreviewData.container())
}

private struct EditRecettePreviewContainer: View {
    @Query(sort: \Recette.nom) private var recettes: [Recette]

    var body: some View {
        Group {
            if let recette = recettes.first {
                EditRecetteView(recette: recette)
            } else {
                ProgressView("Chargement de la recette…")
            }
        }
    }
}

#Preview("Modifier une recette") {
    NavigationStack {
        EditRecettePreviewContainer()
    }
    .modelContainer(PreviewData.container())
}
