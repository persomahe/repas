import Foundation
import SwiftData

struct SemaineExport: Codable {
    let version: Int
    let dateExport: Date
    let semaine: SemaineExportDTO
    let recettes: [RecetteExportDTO]
    let produits: [ProduitExportDTO]
    let tags: [TagExportDTO]
    let course: CourseExportDTO
}

struct SemaineExportDTO: Codable {
    let id: String
    let date: Date
    let recettes: [RecetteSemaineExportDTO]
}

struct RecetteSemaineExportDTO: Codable {
    let recetteID: String
    let nombreDeParts: Int
}

struct TagExportDTO: Codable {
    let id: String
    let nom: String
    let couleurHex: String
}

struct ProduitExportDTO: Codable {
    let id: String
    let nom: String
    let typeUnite: String
    let tagIDs: [String]
}

struct RecetteExportDTO: Codable {
    let id: String
    let nom: String
    let nombreDeParts: Int
    let saisons: [String]
    let tagIDs: [String]
    let lien: String?
    let tempsPreparationMinutes: Int
    let ingredients: [IngredientRecetteExportDTO]
}

struct IngredientRecetteExportDTO: Codable {
    let produitID: String
    let quantite: Double
    let unite: String
}

struct CourseExportDTO: Codable {
    let id: String
    let ingredientsHeritesMaterialises: Bool
    let ingredients: [IngredientCourseExportDTO]
}

struct IngredientCourseExportDTO: Codable {
    let produitID: String
    let quantite: Double
    let quantiteHeriteeDemandee: Double
    let quantiteHeriteeRestante: Double
    let quantiteManuelle: Double
}

@MainActor
enum SemaineExportService {
    enum ExportError: LocalizedError {
        case aucuneSemaine
        case courseAbsente
        case relationIncomplete(String)

        var errorDescription: String? {
            switch self {
            case .aucuneSemaine:
                return "Aucune semaine planifiée à exporter."
            case .courseAbsente:
                return "La liste de courses de la dernière semaine n’existe pas encore. Ouvrez-la une fois avant de l’exporter."
            case .relationIncomplete(let message):
                return message
            }
        }
    }

    static func estExportable(dans context: ModelContext) throws -> Bool {
        guard let semaine = try derniereSemaine(dans: context) else { return false }
        return try coursePour(semaine: semaine, dans: context) != nil
    }

    static func creerFichier(dans context: ModelContext) throws -> URL {
        guard let semaine = try derniereSemaine(dans: context) else {
            throw ExportError.aucuneSemaine
        }
        guard let course = try coursePour(semaine: semaine, dans: context) else {
            throw ExportError.courseAbsente
        }

        let planifications = semaine.recettes
        let recettes = try planifications.map { planification -> RecetteExportDTO in
            guard let recette = planification.recette else {
                throw ExportError.relationIncomplete("Une recette planifiée est introuvable.")
            }
            return recetteDTO(recette)
        }

        let produits = produitsReferencies(parRecettes: planifications, course: course)

        var tagsParID: [String: Tag] = [:]
        for planification in planifications {
            for tag in planification.recette?.tags ?? [] { tagsParID[tag.id] = tag }
        }
        for produit in produits {
            for tagID in produit.tagIDs {
                if let tag = try? trouverTag(id: tagID, dans: context) { tagsParID[tagID] = tag }
            }
        }
        let tags = tagsParID.values.sorted { $0.id < $1.id }.map {
            TagExportDTO(id: $0.id, nom: $0.nom, couleurHex: $0.couleurHex)
        }

        let contenu = SemaineExport(
            version: 1,
            dateExport: .now,
            semaine: SemaineExportDTO(
                id: semaine.id,
                date: semaine.date,
                recettes: planifications.compactMap { planification in
                    guard let recette = planification.recette else { return nil }
                    return RecetteSemaineExportDTO(
                        recetteID: recette.id,
                        nombreDeParts: planification.nombreDeParts
                    )
                }
            ),
            recettes: recettes,
            produits: produits,
            tags: tags,
            course: CourseExportDTO(
                id: course.id,
                ingredientsHeritesMaterialises: course.ingredientsHeritesMaterialises,
                ingredients: course.ingredients.compactMap { ingredient in
                    guard let produit = ingredient.produit else { return nil }
                    return IngredientCourseExportDTO(
                        produitID: produit.id,
                        quantite: ingredient.quantite,
                        quantiteHeriteeDemandee: ingredient.quantiteHeriteeDemandee,
                        quantiteHeriteeRestante: ingredient.quantiteHeriteeRestante,
                        quantiteManuelle: ingredient.quantiteManuelle
                    )
                }
            )
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(contenu)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("repas-semaine.json")
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func derniereSemaine(dans context: ModelContext) throws -> Semaine? {
        var descriptor = FetchDescriptor<Semaine>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private static func coursePour(semaine: Semaine, dans context: ModelContext) throws -> Course? {
        let semaineID = semaine.persistentModelID
        return try context.fetch(FetchDescriptor<Course>()).first {
            $0.semaine?.persistentModelID == semaineID
        }
    }

    private static func recetteDTO(_ recette: Recette) -> RecetteExportDTO {
        RecetteExportDTO(
            id: recette.id,
            nom: recette.nom,
            nombreDeParts: recette.nombreDeParts,
            saisons: recette.saisons.map(\.rawValue),
            tagIDs: recette.tags.map(\.id),
            lien: recette.lien?.absoluteString,
            tempsPreparationMinutes: recette.tempsPreparationMinutes,
            ingredients: recette.ingredients.compactMap { ingredient in
                guard let produit = ingredient.produit else { return nil }
                return IngredientRecetteExportDTO(
                    produitID: produit.id,
                    quantite: ingredient.quantite,
                    unite: ingredient.unite
                )
            }
        )
    }

    private static func produitsReferencies(
        parRecettes planifications: [RecetteSemaine],
        course: Course
    ) -> [ProduitExportDTO] {
        var produits: [String: Produit] = [:]
        for planification in planifications {
            for ingredient in planification.recette?.ingredients ?? [] {
                if let produit = ingredient.produit { produits[produit.id] = produit }
            }
        }
        for ingredient in course.ingredients {
            if let produit = ingredient.produit { produits[produit.id] = produit }
        }
        return produits.values.sorted { $0.id < $1.id }.map {
            ProduitExportDTO(id: $0.id, nom: $0.nom, typeUnite: $0.typeUnite.rawValue, tagIDs: $0.tags.map(\.id))
        }
    }

    private static func trouverTag(id: String, dans context: ModelContext) throws -> Tag? {
        try context.fetch(FetchDescriptor<Tag>()).first { $0.id == id }
    }
}
