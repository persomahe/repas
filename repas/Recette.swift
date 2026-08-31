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
    @Relationship(inverse: \Tag.recettes)
    var tags: [Tag]

    /// Lien vers la recette : URL web (https://…) ou fichier local (file://…, texte ou PDF)
    var lien: URL?

    /// Temps de préparation, en minutes
    var tempsPreparationMinutes: Int

    /// Ingrédients de la recette : couples (produit, quantité).
    /// Supprimer la recette supprime aussi ses lignes d'ingrédients.
    @Relationship(deleteRule: .cascade, inverse: \IngredientRecette.recette)
    var ingredients: [IngredientRecette]

    /// Planifications de cette recette dans des semaines (relation inverse de RecetteSemaine.recette)
    @Relationship(inverse: \RecetteSemaine.recette)
    var semaines: [RecetteSemaine]

    init(
        nom: String,
        nombreDeParts: Int = 4,
        saisons: [Saison] = [],
        tags: [Tag] = [],
        lien: URL? = nil,
        tempsPreparationMinutes: Int = 0,
        ingredients: [IngredientRecette] = [],
        semaines: [RecetteSemaine] = []
    ) {
        self.nom = nom
        self.nombreDeParts = nombreDeParts
        self.saisons = saisons
        self.tags = tags
        self.lien = lien
        self.tempsPreparationMinutes = tempsPreparationMinutes
        self.ingredients = ingredients
        self.semaines = semaines
    }
}

/// Table de liaison : un couple (produit, quantité) appartenant à une recette.
@Model
final class IngredientRecette {
    /// Recette à laquelle appartient ce couple (relation inverse)
    var recette: Recette?

    /// Produit utilisé
    var produit: Produit?

    /// Quantité nécessaire (l'unité pourra être ajoutée plus tard)
    var quantite: Double

    init(recette: Recette? = nil, produit: Produit? = nil, quantite: Double = 1) {
        self.recette = recette
        self.produit = produit
        self.quantite = quantite
    }
}
