import Foundation
import SwiftData

@MainActor
enum SemaineImportService {
    enum ImportError: LocalizedError {
        case fichierInvalide(String)
        case versionNonSupportee(Int)
        case conflitDate(Date)
        case relationIntrouvable(String)
        case quantiteInvalide(String)

        var errorDescription: String? {
            switch self {
            case .fichierInvalide(let message): return message
            case .versionNonSupportee(let version): return "La version d’exportation \(version) n’est pas supportée."
            case .conflitDate(let date):
                return "Une semaine existe déjà à cette date (\(date.formatted(date: .abbreviated, time: .omitted))). Voulez-vous la remplacer ?"
            case .relationIntrouvable(let message): return message
            case .quantiteInvalide(let message): return message
            }
        }
    }

    static func importer(
        depuis url: URL,
        dans context: ModelContext,
        remplacerSemaineDeMemeDate: Bool = false
    ) throws {
        let contenu: SemaineExport
        let accèsSécurisé = url.startAccessingSecurityScopedResource()
        defer {
            if accèsSécurisé {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            contenu = try decoder.decode(SemaineExport.self, from: data)
        } catch let error as DecodingError {
            throw ImportError.fichierInvalide(messagePourDécodage(error))
        } catch {
            throw ImportError.fichierInvalide(
                "Impossible de lire le fichier d’import : \(error.localizedDescription)"
            )
        }

        guard contenu.version == 1 else {
            throw ImportError.versionNonSupportee(contenu.version)
        }
        try valider(contenu)

        let tagsLocaux = try context.fetch(FetchDescriptor<Tag>())
        let produitsLocaux = try context.fetch(FetchDescriptor<Produit>())
        let recettesLocales = try context.fetch(FetchDescriptor<Recette>())
        let semainesLocales = try context.fetch(FetchDescriptor<Semaine>())
        let coursesLocales = try context.fetch(FetchDescriptor<Course>())

        let semaineParID = semainesLocales.first { $0.id == contenu.semaine.id }
        let conflitDeDate = semainesLocales.first {
            $0.date == contenu.semaine.date && $0.id != contenu.semaine.id
        }
        if let conflitDeDate, !remplacerSemaineDeMemeDate {
            throw ImportError.conflitDate(conflitDeDate.date)
        }

        let tagsParID = Dictionary(uniqueKeysWithValues: tagsLocaux.map { ($0.id, $0) })
        for dto in contenu.tags where tagsParID[dto.id] == nil {
            let tag = Tag(id: dto.id, nom: dto.nom, couleurHex: dto.couleurHex)
            context.insert(tag)
        }
        let tousLesTags = try context.fetch(FetchDescriptor<Tag>())
        let tags = Dictionary(uniqueKeysWithValues: tousLesTags.map { ($0.id, $0) })

        let produitsParID = Dictionary(uniqueKeysWithValues: produitsLocaux.map { ($0.id, $0) })
        for dto in contenu.produits where produitsParID[dto.id] == nil {
            guard let typeUnite = TypeUnite(rawValue: dto.typeUnite) else {
                throw ImportError.fichierInvalide("Type d’unité inconnu pour le produit « \(dto.nom) ».")
            }
            let produit = Produit(
                id: dto.id,
                nom: dto.nom,
                typeUnite: typeUnite,
                tags: dto.tagIDs.compactMap { tags[$0] }
            )
            context.insert(produit)
        }
        let tousLesProduits = try context.fetch(FetchDescriptor<Produit>())
        let produits = Dictionary(uniqueKeysWithValues: tousLesProduits.map { ($0.id, $0) })

        let recettesParID = Dictionary(uniqueKeysWithValues: recettesLocales.map { ($0.id, $0) })
        for dto in contenu.recettes where recettesParID[dto.id] == nil {
            let recette = Recette(
                id: dto.id,
                nom: dto.nom,
                nombreDeParts: dto.nombreDeParts,
                saisons: dto.saisons.compactMap(Saison.init(rawValue:)),
                tags: dto.tagIDs.compactMap { tags[$0] },
                lien: dto.lien.flatMap(URL.init(string:)),
                tempsPreparationMinutes: dto.tempsPreparationMinutes
            )
            context.insert(recette)
            let ingredients = try dto.ingredients.map { ingredientDTO -> IngredientRecette in
                guard let produit = produits[ingredientDTO.produitID] else {
                    throw ImportError.relationIntrouvable("Le produit « \(ingredientDTO.produitID) » est introuvable.")
                }
                let ingredient = IngredientRecette(
                    recette: recette,
                    produit: produit,
                    quantite: ingredientDTO.quantite,
                    unite: ingredientDTO.unite
                )
                context.insert(ingredient)
                return ingredient
            }
            recette.ingredients = ingredients
        }
        let toutesLesRecettes = try context.fetch(FetchDescriptor<Recette>())
        let recettes = Dictionary(uniqueKeysWithValues: toutesLesRecettes.map { ($0.id, $0) })

        // Les suppressions sont effectuées seulement après toutes les validations et résolutions.
        if let semaineLoc = semaineParID { context.delete(semaineLoc) }
        if let conflitDeDate, remplacerSemaineDeMemeDate { context.delete(conflitDeDate) }
        for course in coursesLocales where course.id == contenu.course.id || course.semaine?.date == contenu.semaine.date {
            context.delete(course)
        }

        let semaine = Semaine(id: contenu.semaine.id, date: contenu.semaine.date)
        context.insert(semaine)
        semaine.recettes = try contenu.semaine.recettes.map { planificationDTO in
            guard let recette = recettes[planificationDTO.recetteID] else {
                throw ImportError.relationIntrouvable("La recette « \(planificationDTO.recetteID) » est introuvable.")
            }
            let planification = RecetteSemaine(recette: recette, nombreDeParts: planificationDTO.nombreDeParts)
            context.insert(planification)
            planification.semaine = semaine
            return planification
        }

        let course = Course(
            id: contenu.course.id,
            semaine: semaine,
            ingredientsHeritesMaterialises: contenu.course.ingredientsHeritesMaterialises
        )
        context.insert(course)
        course.ingredients = try contenu.course.ingredients.map { ingredientDTO in
            guard let produit = produits[ingredientDTO.produitID] else {
                throw ImportError.relationIntrouvable("Le produit « \(ingredientDTO.produitID) » est introuvable dans la course.")
            }
            guard ingredientDTO.quantite >= 0,
                  ingredientDTO.quantiteHeriteeDemandee >= 0,
                  ingredientDTO.quantiteHeriteeRestante >= 0,
                  ingredientDTO.quantiteManuelle >= 0 else {
                throw ImportError.quantiteInvalide("Une quantité négative a été trouvée pour « \(ingredientDTO.produitID) ».")
            }
            let ingredient = IngredientCourse(
                course: course,
                produit: produit,
                quantite: ingredientDTO.quantite,
                quantiteHeriteeDemandee: ingredientDTO.quantiteHeriteeDemandee,
                quantiteHeriteeRestante: ingredientDTO.quantiteHeriteeRestante,
                quantiteManuelle: ingredientDTO.quantiteManuelle
            )
            context.insert(ingredient)
            return ingredient
        }

        try context.save()
    }

    private static func messagePourDécodage(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "Le fichier d’import est incomplet : clé « \(key.stringValue) » absente (\(chemin(context)))."
        case .typeMismatch(_, let context):
            return "Le format du fichier d’import est incorrect (\(chemin(context)))."
        case .valueNotFound(_, let context):
            return "Une valeur obligatoire est absente du fichier d’import (\(chemin(context)))."
        case .dataCorrupted(let context):
            return "Le fichier d’import contient une valeur invalide (\(chemin(context)))."
        @unknown default:
            return "Ce fichier n’est pas un export valide de l’application Repas."
        }
    }

    private static func chemin(_ context: DecodingError.Context) -> String {
        let chemin = context.codingPath.map(\.stringValue).joined(separator: ".")
        return chemin.isEmpty ? "racine" : chemin
    }

    private static func valider(_ contenu: SemaineExport) throws {
        let idsTags = contenu.tags.map(\.id)
        let idsProduits = contenu.produits.map(\.id)
        let idsRecettes = contenu.recettes.map(\.id)
        guard !contenu.semaine.id.isEmpty,
              Set(idsTags).count == idsTags.count,
              Set(idsProduits).count == idsProduits.count,
              Set(idsRecettes).count == idsRecettes.count else {
            throw ImportError.fichierInvalide("Le fichier contient des identifiants manquants ou dupliqués.")
        }
        for recette in contenu.recettes {
            for ingredient in recette.ingredients where !idsProduits.contains(ingredient.produitID) {
                throw ImportError.relationIntrouvable("Le produit « \(ingredient.produitID) » est absent du fichier.")
            }
        }
        for planification in contenu.semaine.recettes where !idsRecettes.contains(planification.recetteID) {
            throw ImportError.relationIntrouvable("La recette « \(planification.recetteID) » est absente du fichier.")
        }
        for ingredient in contenu.course.ingredients where !idsProduits.contains(ingredient.produitID) {
            throw ImportError.relationIntrouvable("Le produit « \(ingredient.produitID) » est absent de la course.")
        }
    }
}

private extension Array where Element == any CodingKey {
    var codingPathDescription: String {
        isEmpty ? "racine" : map(\.stringValue).joined(separator: ".")
    }
}
