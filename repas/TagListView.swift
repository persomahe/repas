//
//  TagListView.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

/// Écran affichant la liste des tags enregistrés dans la base.
struct TagListView: View {
    @Environment(\.modelContext) private var context

    /// Récupère automatiquement tous les tags, triés par nom
    @Query(sort: \Tag.nom) private var tags: [Tag]

    /// Produits pour vérifier si un tag est utilisé.
    @Query(sort: \Produit.nom) private var produits: [Produit]

    /// Recettes pour vérifier si un tag est utilisé.
    @Query(sort: \Recette.nom) private var recettes: [Recette]

    /// Contrôle l'affichage de la fiche de création d'un tag
    @State private var ajoutEnCours = false

    /// Tag sélectionné pour consultation / modification.
    @State private var tagAEditer: Tag?

    /// Tag sélectionné pour suppression (avec confirmation).
    @State private var tagASupprimer: Tag?

    var body: some View {
        List {
            ForEach(tags.indices, id: \.self) { index in
                tagRow(tags[index])
            }
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Ajouter un tag", systemImage: "plus") {
                    ajoutEnCours = true
                }
            }
        }
        .sheet(isPresented: $ajoutEnCours) {
            NouveauTagView()
        }
        .sheet(item: $tagAEditer) { tag in
            EditTagView(tag: tag)
        }
        .confirmationDialog(
            "Supprimer ce tag ?",
            isPresented: suppressionDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let tagASupprimer {
                    context.delete(tagASupprimer)
                }
                tagASupprimer = nil
            }
            Button("Annuler", role: .cancel) {
                tagASupprimer = nil
            }
        } message: {
            Text(suppressionMessage)
        }
        .overlay {
            if tags.isEmpty {
                ContentUnavailableView(
                    "Aucun tag",
                    systemImage: "tag",
                    description: Text("Les tags que tu créeras apparaîtront ici.")
                )
            }
        }
    }

    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        HStack {
            Circle()
                .fill(Color(hex: tag.couleurHex))
                .frame(width: 12, height: 12)
            Text(tag.nom)

            Spacer()

            Button {
                tagAEditer = tag
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modifier le tag \(tag.nom)")

            Button {
                tagASupprimer = tag
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(estTagUtilise(tag) ? Color.secondary : Color.red)
            .disabled(estTagUtilise(tag))
            .accessibilityLabel(Text("Supprimer le tag"))
        }
    }

    private func estTagUtilise(_ tag: Tag) -> Bool {
        let tagID = tag.persistentModelID

        let utiliseParProduit = produits.contains { produit in
            produit.tags.contains { $0.persistentModelID == tagID }
        }

        if utiliseParProduit {
            return true
        }

        return recettes.contains { recette in
            recette.tags.contains { $0.persistentModelID == tagID }
        }
    }

    private var suppressionDialogBinding: Binding<Bool> {
        Binding(
            get: { tagASupprimer != nil },
            set: { if !$0 { tagASupprimer = nil } }
        )
    }

    private var suppressionMessage: String {
        guard let nom = tagASupprimer?.nom, !nom.isEmpty else {
            return "Ce tag sera supprime definitivement."
        }
        return "Le tag \(nom) sera supprime definitivement."
    }
}

/// Fiche de création d'un nouveau tag (nom + couleur).
struct NouveauTagView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var nom = ""
    @State private var couleurHex = "#007AFF"

    /// Palette de couleurs proposées
    private let couleurs = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#8E8E93"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du tag", text: $nom)

                Section("Couleur") {
                    HStack {
                        ForEach(couleurs, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if hex == couleurHex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                                .onTapGesture { couleurHex = hex }
                        }
                    }
                }
            }
            .navigationTitle("Nouveau tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        context.insert(Tag(nom: nom.trimmingCharacters(in: .whitespaces), couleurHex: couleurHex))
                        dismiss()
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

/// Fiche de consultation / modification d'un tag existant.
struct EditTagView: View {
    let tag: Tag

    @Environment(\.dismiss) private var dismiss

    @State private var nom: String
    @State private var couleurHex: String

    /// Palette de couleurs proposées
    private let couleurs = ["#007AFF", "#34C759", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#8E8E93"]

    init(tag: Tag) {
        self.tag = tag
        _nom = State(initialValue: tag.nom)
        _couleurHex = State(initialValue: tag.couleurHex)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du tag", text: $nom)

                Section("Couleur") {
                    HStack {
                        ForEach(couleurs, id: \.self) { hex in
                            Circle()
                                .fill(Color(hex: hex))
                                .frame(width: 30, height: 30)
                                .overlay {
                                    if hex == couleurHex {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.white)
                                            .fontWeight(.bold)
                                    }
                                }
                                .onTapGesture { couleurHex = hex }
                        }
                    }
                }
            }
            .navigationTitle("Modifier le tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        tag.nom = nom.trimmingCharacters(in: .whitespaces)
                        tag.couleurHex = couleurHex
                        dismiss()
                    }
                    .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

extension Color {
    /// Crée une couleur à partir d'une chaîne hexadécimale (ex. "#FF5733")
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }
}

#Preview {
    NavigationStack {
        TagListView()
    }
    .modelContainer(PreviewData.container())
}
