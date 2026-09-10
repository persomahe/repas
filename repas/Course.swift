//
//  Course.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import Foundation
import SwiftData

/// Table des courses : une liste de courses, associée à une semaine.
@Model
final class Course {
    /// Semaine de la course.
    var semaine: Semaine?

    /// Couples (produit, quantité) à acheter.
    /// Supprimer la course supprime aussi ses lignes d'ingrédients.
    @Relationship(deleteRule: .cascade, inverse: \IngredientCourse.course)
    var ingredients: [IngredientCourse]

    /// Indique que les besoins des recettes ont été copiés dans la course.
    var ingredientsHeritesMaterialises: Bool

    init(
        semaine: Semaine? = nil,
        ingredients: [IngredientCourse] = [],
        ingredientsHeritesMaterialises: Bool = false
    ) {
        self.semaine = semaine
        self.ingredients = ingredients
        self.ingredientsHeritesMaterialises = ingredientsHeritesMaterialises
    }

    /// Copie une seule fois les besoins de la semaine dans la liste persistée.
    func materialiserIngredientsHerites() {
        guard !ingredientsHeritesMaterialises, let semaine else { return }

        var besoins: [PersistentIdentifier: (produit: Produit, quantite: Double)] = [:]
        for planification in semaine.recettes {
            guard let recette = planification.recette, recette.nombreDeParts > 0 else { continue }
            let ratio = Double(planification.nombreDeParts) / Double(recette.nombreDeParts)

            for ingredient in recette.ingredients {
                guard let produit = ingredient.produit else { continue }
                let id = produit.persistentModelID
                besoins[id, default: (produit: produit, quantite: 0)].quantite += ingredient.quantite * ratio
            }
        }

        for ingredient in ingredients {
            // Les lignes existantes avant cette évolution sont considérées comme manuelles.
            if ingredient.quantiteHeriteeDemandee == 0,
               ingredient.quantiteHeriteeRestante == 0,
               ingredient.quantiteManuelle == 0 {
                ingredient.quantiteManuelle = ingredient.quantite
            }
        }

        for besoin in besoins.values {
            if let ingredient = ingredients.first(where: { $0.produit?.persistentModelID == besoin.produit.persistentModelID }) {
                ingredient.quantiteHeriteeDemandee = besoin.quantite
                ingredient.quantiteHeriteeRestante = besoin.quantite
            } else {
                ingredients.append(
                    IngredientCourse(
                        course: self,
                        produit: besoin.produit,
                        quantite: besoin.quantite,
                        quantiteHeriteeDemandee: besoin.quantite,
                        quantiteHeriteeRestante: besoin.quantite,
                        quantiteManuelle: 0
                    )
                )
            }
        }

        ingredientsHeritesMaterialises = true
    }
}

/// Table de liaison : un couple (produit, quantité) appartenant à une course.
@Model
final class IngredientCourse {
    /// Course à laquelle appartient ce couple (relation inverse)
    var course: Course?

    /// Produit utilisé
    var produit: Produit?

    /// Quantité affichée historiquement. Elle reste synchronisée avec les deux origines.
    var quantite: Double

    /// Quantité héritée encore présente dans la liste.
    var quantiteHeriteeRestante: Double

    /// Quantité héritée demandée lors de la matérialisation.
    var quantiteHeriteeDemandee: Double

    /// Quantité ajoutée manuellement.
    var quantiteManuelle: Double

    init(
        course: Course? = nil,
        produit: Produit? = nil,
        quantite: Double = 1,
        quantiteHeriteeDemandee: Double = 0,
        quantiteHeriteeRestante: Double = 0,
        quantiteManuelle: Double? = nil
    ) {
        self.course = course
        self.produit = produit
        self.quantite = quantite
        self.quantiteHeriteeDemandee = quantiteHeriteeDemandee
        self.quantiteHeriteeRestante = quantiteHeriteeRestante
        self.quantiteManuelle = quantiteManuelle ?? quantite
    }

    func mettreAJourQuantite() {
        quantite = max(0, quantiteHeriteeRestante) + max(0, quantiteManuelle)
    }
}
