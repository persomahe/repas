//
//  Ingredient.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import Foundation
import SwiftData

/// Classe de base : un couple (produit, quantité) utilisé dans une recette ou une course.
@Model
class Ingredient {
    /// Produit utilisé
    var produit: Produit?

    /// Quantité nécessaire (l'unité pourra être ajoutée plus tard)
    var quantite: Double

    init(produit: Produit? = nil, quantite: Double = 1) {
        self.produit = produit
        self.quantite = quantite
    }
}
