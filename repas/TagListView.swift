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
