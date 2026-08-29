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
    /// Récupère automatiquement tous les tags, triés par nom
    @Query(sort: \Tag.nom) private var tags: [Tag]

    /// Contrôle l'affichage de la fiche de création d'un tag
    @State private var ajoutEnCours = false

    var body: some View {
        List(tags) { tag in
            HStack {
                Circle()
                    .fill(Color(hex: tag.couleurHex))
                    .frame(width: 12, height: 12)
                Text(tag.nom)
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
    .modelContainer(for: Tag.self, inMemory: true)
}
