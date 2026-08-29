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
    /// Récupère automatiquement tous les produits, triés par nom
    @Query(sort: \Produit.nom) private var produits: [Produit]

    /// Contrôle l'affichage de la fiche de création d'un produit
    @State private var ajoutEnCours = false

    var body: some View {
        List(produits) { produit in
            VStack(alignment: .leading, spacing: 4) {
                Text(produit.nom)
                if !produit.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(produit.tags) { tag in
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
}

/// Fiche de création d'un nouveau produit (nom + tags).
struct NouveauProduitView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Tous les tags existants, pour la sélection
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]

    @State private var nom = ""
    @State private var tagsChoisis: Set<Tag> = []

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du produit", text: $nom)

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
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        context.insert(Produit(nom: nom.trimmingCharacters(in: .whitespaces), tags: Array(tagsChoisis)))
                        dismiss()
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProduitListView()
    }
    .modelContainer(for: [Tag.self, Produit.self], inMemory: true)
}
