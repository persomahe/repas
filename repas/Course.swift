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

    init(semaine: Semaine? = nil, ingredients: [IngredientCourse] = []) {
        self.semaine = semaine
        self.ingredients = ingredients
    }
}

/// Table de liaison : un couple (produit, quantité) appartenant à une course.
@available(iOS 26.0, macOS 26.0, *)
@Model
final class IngredientCourse: Ingredient {
    /// Course à laquelle appartient ce couple (relation inverse)
    var course: Course?

    init(course: Course? = nil, produit: Produit? = nil, quantite: Double = 1) {
        self.course = course
        super.init(produit: produit, quantite: quantite)
    }
}
