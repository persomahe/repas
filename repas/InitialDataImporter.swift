import Foundation
import SwiftData

/// Importe le catalogue JSON fourni avec l'application lors du premier lancement.
enum InitialDataImporter {
    private struct Catalogue: Decodable {
        let version: Int
        let tags: [TagDTO]
        let produits: [ProduitDTO]
        let recettes: [RecetteDTO]
    }

    private struct TagDTO: Decodable {
        let id: String
        let nom: String
        let couleurHex: String
    }

    private struct ProduitDTO: Decodable {
        let id: String
        let nom: String
        let typeUnite: TypeUnite
        let tags: [String]
    }

    private struct RecetteDTO: Decodable {
        let id: String
        let nom: String
        let nombreDeParts: Int
        let saisons: [Saison]
        let tags: [String]
        let lien: URL?
        let tempsPreparationMinutes: Int
        let ingredients: [IngredientDTO]

        enum CodingKeys: String, CodingKey {
            case id, nom, nombreDeParts, saisons, tags, lien
            case tempsPreparationMinutes, ingredients
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            nom = try container.decode(String.self, forKey: .nom)
            nombreDeParts = try container.decode(Int.self, forKey: .nombreDeParts)
            tags = try container.decode([String].self, forKey: .tags)
            lien = try container.decodeIfPresent(URL.self, forKey: .lien)
            tempsPreparationMinutes = try container.decode(Int.self, forKey: .tempsPreparationMinutes)
            ingredients = try container.decode([IngredientDTO].self, forKey: .ingredients)

            let valeursSaisons = try container.decode([String].self, forKey: .saisons)
            saisons = try valeursSaisons.map { valeur in
                switch valeur
                    .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                    .lowercased() {
                case "printemps": return .printemps
                case "ete": return .ete
                case "automne": return .automne
                case "hiver": return .hiver
                default:
                    throw DecodingError.dataCorruptedError(
                        forKey: .saisons,
                        in: container,
                        debugDescription: "Saison inconnue : \(valeur)"
                    )
                }
            }
        }
    }

    private struct IngredientDTO: Decodable {
        let produit: String
        let quantite: Double
        let unite: String?
    }

    @MainActor
    static func importerSiNecessaire(dans context: ModelContext) throws {
        let catalogue = try chargerCatalogue()

        // Les installations ayant déjà importé le catalogue reçoivent aussi les temps corrigés.
        if try !context.fetch(FetchDescriptor<Tag>()).isEmpty {
            var aSauvegarder = false
            for recette in try context.fetch(FetchDescriptor<Recette>()) {
                if recette.tempsPreparationMinutes == 0,
                   let dto = catalogue.recettes.first(where: { $0.nom == recette.nom }),
                   let temps = RecipePreparationTimes.byID[dto.id] ?? (dto.tempsPreparationMinutes > 0 ? dto.tempsPreparationMinutes : nil) {
                    recette.tempsPreparationMinutes = temps
                    aSauvegarder = true
                }
            }
            if aSauvegarder { try context.save() }
            return
        }

        // Le catalogue ne doit être ajouté qu'une seule fois.
        guard try context.fetch(FetchDescriptor<Tag>()).isEmpty else {
            return
        }

        var tagsParID: [String: Tag] = [:]
        for dto in catalogue.tags {
            let tag = Tag(nom: dto.nom, couleurHex: dto.couleurHex)
            context.insert(tag)
            tagsParID[dto.id] = tag
        }

        var produitsParID: [String: Produit] = [:]
        for dto in catalogue.produits {
            let tags = dto.tags.compactMap { tagsParID[$0] }
            let produit = Produit(
                nom: dto.nom,
                typeUnite: dto.typeUnite,
                tags: tags
            )
            context.insert(produit)
            produitsParID[dto.id] = produit
        }

        for dto in catalogue.recettes {
            let tags = dto.tags.compactMap { tagsParID[$0] }
            let recette = Recette(
                nom: dto.nom,
                nombreDeParts: dto.nombreDeParts,
                saisons: dto.saisons,
                tags: tags,
                lien: dto.lien,
                tempsPreparationMinutes: RecipePreparationTimes.byID[dto.id] ?? dto.tempsPreparationMinutes
            )
            context.insert(recette)

            let ingredients = dto.ingredients.compactMap { ingredientDTO -> IngredientRecette? in
                guard let produit = produitsParID[ingredientDTO.produit] else {
                    return nil
                }

                let ingredient = IngredientRecette(
                    recette: recette,
                    produit: produit,
                    quantite: ingredientDTO.quantite,
                    unite: ingredientDTO.unite ?? ""
                )
                context.insert(ingredient)
                return ingredient
            }
            recette.ingredients = ingredients
        }

        try context.save()
    }

    private static func chargerCatalogue() throws -> Catalogue {
        guard let url = Bundle.main.url(forResource: "donnees_initiales", withExtension: "json") else {
            throw ImportError.fichierIntrouvable
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Catalogue.self, from: data)
    }

    enum ImportError: LocalizedError {
        case fichierIntrouvable

        var errorDescription: String? {
            switch self {
            case .fichierIntrouvable:
                return "Le fichier donnees_initiales.json est absent du bundle de l'application."
            }
        }
    }
}
