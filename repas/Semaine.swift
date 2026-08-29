//
//  Semaine.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import Foundation
import SwiftData

/// Table des semaines : une semaine de repas, identifiée par la date
@Model
final class Semaine {
    /// Date de la semaine, unique dans la base
    @Attribute(.unique) var date: Date

    /// Recettes prévues pour cette semaine, chacune avec son nombre de parts.
    /// Supprimer la semaine supprime aussi ses lignes de planification.
    @Relationship(deleteRule: .cascade, inverse: \RecetteSemaine.semaine)
    var recettes: [RecetteSemaine]

    init(date: Date, recettes: [RecetteSemaine] = []) {
        self.date = date
        self.recettes = recettes
    }

    /// Nombre total de parts à préparer pour la semaine.
    var nombreTotalDeParts: Int {
        recettes.reduce(0) { $0 + $1.nombreDeParts }
    }
}

/// Table de liaison : une recette planifiée dans une semaine, avec son nombre de parts.
@Model
final class RecetteSemaine {
    /// Recette planifiée
    var recette: Recette?

    /// Nombre de parts à préparer pour cette recette
    var nombreDeParts: Int

    /// Semaine à laquelle appartient cette planification (relation inverse)
    var semaine: Semaine?

    init(recette: Recette? = nil, nombreDeParts: Int = 1) {
        self.recette = recette
        self.nombreDeParts = nombreDeParts
    }
}
