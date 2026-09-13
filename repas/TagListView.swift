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

    @State private var afficherInformations = false

    var body: some View {
        ZStack {
            FondPageBackground()

            List {
                ForEach(tags.indices, id: \.self) { index in
                    tagRow(tags[index])
                }
            }
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
        }
        .navigationTitle("Tags")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Ajouter un tag", systemImage: "plus") {
                    ajoutEnCours = true
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    afficherInformations = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("Afficher les informations")
            }
        }
        .sheet(isPresented: $ajoutEnCours) {
            NouveauTagView()
        }
        .sheet(item: $tagAEditer) { tag in
            EditTagView(tag: tag)
        }
        .sheet(isPresented: $afficherInformations) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        let texte = AttributedString("""
                        Liste des tags déjà enregistrés dans l'application.\n
                        """)
                        Text(texte)

                        Text("Fonctionnement général")
                            .font(.headline)
                        Text("Ajout :")
                            .underline()
                        let texte2 = AttributedString("""
                        - Cliquez sur + (en haut à droite) :
                        saisissez son nom et sa couleur.
                        - Les tags vous serviront à filtrer (trier) les produtits ou les recettes.
                        """)
                        Text(texte2)
                        Text("Modification :")
                            .underline()
                        let texte3 = AttributedString("""
                        - Cliquez sur un tag pour l'éditer.
                        """)
                        Text(texte3)
                        Text("Suppression :")
                            .underline()
                        let texte4 = AttributedString("""
                        - Pour supprimer un tag de la liste, glissez vers la gauche le tag : une demande de confirmation apparaîtra.
                        - Vous pourrez supprimer un tag même s'il est utilisé par un produit ou une recette. Cela ne supprime que le tag.
                        """)
                        Text(texte4)
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
                .tint(Color(hex: "#C3360B"))
            }
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

        }
        .contentShape(Rectangle())
        .onTapGesture {
            tagAEditer = tag
        }
        .accessibilityAction(named: Text("Modifier le tag")) {
            tagAEditer = tag
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                Button(role: .destructive) {
                    tagASupprimer = tag
                } label: {
                    Label("Supprimer", systemImage: "trash")
                }
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
    @State private var dernierAjout: String?

    /// Palette de couleurs proposées
    private let couleurs = ["#007AFF", "#34C759", "#FFCC00", "#FF9500", "#FF3B30", "#AF52DE", "#5856D6", "#FF2D55", "#8B4513", "#8E8E93"]

    var body: some View {
        NavigationStack {
            Form {
                TextField("Nom du tag", text: $nom)

                if let dernierAjout {
                    Label("« \(dernierAjout) » ajouté", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

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
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#F8E1C3").ignoresSafeArea())
            .navigationTitle("Nouveau tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter") {
                        let nomNettoye = nom.trimmingCharacters(in: .whitespaces)
                        guard !nomNettoye.isEmpty else { return }

                        context.insert(Tag(nom: nomNettoye, couleurHex: couleurHex))
                        dernierAjout = nomNettoye
                        nom = ""
                        couleurHex = "#007AFF"
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
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#F8E1C3").ignoresSafeArea())
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
