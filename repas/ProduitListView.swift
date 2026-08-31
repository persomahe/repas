//
//  ProduitListView.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

/// Écran affichant la liste des produits enregistrés dans la base.
struct ProduitListView: View {
    @Environment(\.modelContext) private var context

    /// Récupère automatiquement tous les produits, triés par nom
    @Query(sort: \Produit.nom) private var produits: [Produit]

    /// Recettes pour vérifier si un produit est utilisé.
    @Query(sort: \Recette.nom) private var recettes: [Recette]

    /// Contrôle l'affichage de la fiche de création d'un produit
    @State private var ajoutEnCours = false

    /// Produit sélectionné pour consultation / modification.
    @State private var produitAEditer: Produit?

    /// Produit sélectionné pour suppression (avec confirmation).
    @State private var produitASupprimer: Produit?

    var body: some View {
        List {
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 70), spacing: 12)],
                spacing: 12
            ) {
                ForEach(produits) { produit in
                    produitRow(produit)
                }
            }
            .padding(.vertical, 8)
        }
        .navigationTitle("Produits")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Ajouter un produit", systemImage: "plus") {
                    ajoutEnCours = true
                }
            }
        }
        .sheet(isPresented: $ajoutEnCours) {
            NouveauProduitView()
        }
        .sheet(item: $produitAEditer) { produit in
            EditProduitView(produit: produit)
        }
        .confirmationDialog(
            "Supprimer ce produit ?",
            isPresented: suppressionDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let produitASupprimer {
                    context.delete(produitASupprimer)
                }
                produitASupprimer = nil
            }
            Button("Annuler", role: .cancel) {
                produitASupprimer = nil
            }
        } message: {
            Text(suppressionMessage)
        }
        .overlay {
            if produits.isEmpty {
                ContentUnavailableView(
                    "Aucun produit",
                    systemImage: "carrot",
                    description: Text("Les produits que tu créeras apparaîtront ici.")
                )
            }
        }
    }

    @ViewBuilder
    private func produitRow(_ produit: Produit) -> some View {
        VStack(spacing: 6) {
            Text(produit.nom)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !produit.tags.isEmpty {
                HStack(spacing: 3) {
                    ForEach(produit.tags) { tag in
                        Circle()
                            .fill(Color(hex: tag.couleurHex))
                            .frame(width: 8, height: 8)
                    }
                }
            }

            HStack(spacing: 14) {
                Button {
                    produitAEditer = produit
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Modifier le produit \(produit.nom)")

                Button {
                    produitASupprimer = produit
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(estProduitUtilise(produit) ? Color.secondary : Color.red)
                .disabled(estProduitUtilise(produit))
                .accessibilityLabel(Text("Supprimer le produit"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 60)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func estProduitUtilise(_ produit: Produit) -> Bool {
        let produitID = produit.persistentModelID

        return recettes.contains { recette in
            recette.ingredients.contains { ingredient in
                ingredient.produit?.persistentModelID == produitID
            }
        }
    }

    private var suppressionDialogBinding: Binding<Bool> {
        Binding(
            get: { produitASupprimer != nil },
            set: { if !$0 { produitASupprimer = nil } }
        )
    }

    private var suppressionMessage: String {
        guard let nom = produitASupprimer?.nom, !nom.isEmpty else {
            return "Ce produit sera supprime definitivement."
        }
        return "Le produit \(nom) sera supprime definitivement."
    }
}

/// Fiche de création d'un nouveau produit (nom + tags).
struct NouveauProduitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Tous les tags existants, pour la sélection
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]

    @State private var nom = ""
    @State private var tagsChoisis: Set<Tag> = []

    /// Nom du dernier produit ajouté, pour afficher une confirmation
    @State private var dernierAjout: String?

    /// Garde le focus sur le champ nom pour enchaîner les saisies
    @FocusState private var nomFocalise: Bool

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du produit", text: $nom)
                    .focused($nomFocalise)
                    .onSubmit(ajouterProduit)

                if let dernierAjout {
                    Label("« \(dernierAjout) » ajouté", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Section("Tags") {
                    if tousLesTags.isEmpty {
                        Text("Aucun tag disponible. Crée d'abord des tags depuis la liste des tags.")
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
            .navigationTitle("Nouveau produit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter", action: ajouterProduit)
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    /// Enregistre le produit puis réinitialise le formulaire pour la saisie suivante.
    private func ajouterProduit() {
        let nomNettoye = nom.trimmingCharacters(in: .whitespaces)
        guard !nomNettoye.isEmpty else { return }

        context.insert(Produit(nom: nomNettoye, tags: Array(tagsChoisis)))
        dernierAjout = nomNettoye

        // Réinitialise le formulaire sans fermer la fiche
        nom = ""
        tagsChoisis = []
        nomFocalise = true
    }
}

/// Fiche de consultation / modification d'un produit existant.
struct EditProduitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Produit en cours de consultation / modification.
    let produit: Produit

    /// Tous les tags existants, pour la sélection
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]

    @State private var nom: String
    @State private var tagsChoisis: Set<Tag>

    init(produit: Produit) {
        self.produit = produit
        _nom = State(initialValue: produit.nom)
        _tagsChoisis = State(initialValue: Set(produit.tags))
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du produit", text: $nom)

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
            .navigationTitle("Modifier le produit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: enregistrer)
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    /// Applique les modifications au produit puis ferme la fiche.
    private func enregistrer() {
        let nomNettoye = nom.trimmingCharacters(in: .whitespaces)
        guard !nomNettoye.isEmpty else { return }

        produit.nom = nomNettoye
        produit.tags = Array(tagsChoisis)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ProduitListView()
    }
    .modelContainer(PreviewData.container())
}

#Preview {
    NavigationStack {
        EditProduitView(produit: Produit(nom: "Tomates"))
    }
    .modelContainer(PreviewData.container())
}
