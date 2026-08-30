//
//  Produit.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import Foundation
import SwiftData

/// Table des produits : un aliment ou ingrédient, étiqueté par des tags.
@Model
final class Produit {
    /// Nom du produit, unique dans la base
    @Attribute(.unique) var nom: String

    /// Tags associés au produit (relation plusieurs-à-plusieurs avec la table Tag)
    @Relationship(inverse: \Tag.produits)
    var tags: [Tag]

    init(nom: String, tags: [Tag] = []) {
        self.nom = nom
        self.tags = tags
    }
}
