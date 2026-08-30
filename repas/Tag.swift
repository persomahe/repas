//
//  Tag.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import Foundation
import SwiftData

/// Table des tags : permet d'étiqueter les éléments de l'app (ex. « végétarien », « rapide », « été »).
@Model
final class Tag {
    /// Nom du tag, unique dans la base
    @Attribute(.unique) var nom: String

    /// Couleur du tag, stockée en hexadécimal (ex. "#FF5733")
    var couleurHex: String

    /// Date de création du tag
    var dateCreation: Date

    /// Produits associés à ce tag (relation inverse de Produit.tags)
    var produits: [Produit] = []

    init(nom: String, couleurHex: String = "#007AFF", dateCreation: Date = .now) {
        self.nom = nom
        self.couleurHex = couleurHex
        self.dateCreation = dateCreation
    }
}
