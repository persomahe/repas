//
//  Recette.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import Foundation
import SwiftData

/// Saison associée à une recette.
enum Saison: String, Codable, CaseIterable, Identifiable {
    case printemps = "Printemps"
    case ete = "Été"
    case automne = "Automne"
    case hiver = "Hiver"

    var id: String { rawValue }
}

/// Table des recettes.
@Model
final class Recette {
    /// Nom de la recette, unique dans la base
    @Attribute(.unique) var nom: String

    /// Nombre de parts que produit la recette
    var nombreDeParts: Int

    /// Saisons de la recette (une recette peut convenir à plusieurs saisons)
    var saisons: [Saison]

    /// Tags associés (relation plusieurs-à-plusieurs avec la table Tag)
    var tags: [Tag]

    /// Lien vers la recette : URL web (https://…) ou fichier local (file://…, texte ou PDF)
    var lien: URL?

    /// Temps de préparation, en minutes
    var tempsPreparationMinutes: Int

    /// Ingrédients de la recette : couples (produit, quantité).
    /// Supprimer la recette supprime aussi ses lignes d'ingrédients.
    @Relationship(deleteRule: .cascade, inverse: \IngredientRecette.recette)
    var ingredients: [IngredientRecette]

    init(
        nom: String,
        nombreDeParts: Int = 4,
        saisons: [Saison] = [],
        tags: [Tag] = [],
        lien: URL? = nil,
        tempsPreparationMinutes: Int = 0,
        ingredients: [IngredientRecette] = []
    ) {
        self.nom = nom
        self.nombreDeParts = nombreDeParts
        self.saisons = saisons
        self.tags = tags
        self.lien = lien
        self.tempsPreparationMinutes = tempsPreparationMinutes
        self.ingredients = ingredients
    }
}

/// Table de liaison : un couple (produit, quantité) appartenant à une recette.
@available(iOS 26.0, macOS 26.0, *)
@Model
final class IngredientRecette: Ingredient {
    /// Recette à laquelle appartient ce couple (relation inverse)
    var recette: Recette?

    init(recette: Recette? = nil, produit: Produit? = nil, quantite: Double = 1) {
        self.recette = recette
        super.init(produit: produit, quantite: quantite)
    }
}
