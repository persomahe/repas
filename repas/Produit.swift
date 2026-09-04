//
//  Produit.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import Foundation
import SwiftData

/// Type d'unité utilisé pour quantifier un produit.
enum TypeUnite: String, Codable, CaseIterable, Identifiable {
    case piece = "à la pièce"
    case poids = "au poids"

    var id: String { rawValue }

    var pas: Double {
        self == .piece ? 1 : 100
    }
}

/// Table des produits : un aliment ou ingrédient, étiqueté par des tags.
@Model
final class Produit {
    /// Nom du produit, unique dans la base
    @Attribute(.unique) var nom: String

    /// Tags associés au produit (relation plusieurs-à-plusieurs avec la table Tag)
    @Relationship(inverse: \Tag.produits)
    var tags: [Tag]

    /// Type d'unité utilisé par défaut dans les recettes et la liste de courses.
    var typeUnite: TypeUnite

    init(nom: String, typeUnite: TypeUnite = .piece, tags: [Tag] = []) {
        self.nom = nom
        self.typeUnite = typeUnite
        self.tags = tags
    }
}
