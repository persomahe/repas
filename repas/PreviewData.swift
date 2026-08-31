import SwiftUI
import SwiftData

/// Données communes, isolées en mémoire, utilisées par tous les aperçus Xcode.
enum PreviewData {
    static func container() -> ModelContainer {
        let schema = Schema([
            Tag.self,
            Produit.self,
            Recette.self,
            IngredientRecette.self,
            Semaine.self,
            RecetteSemaine.self,
            Course.self,
            IngredientCourse.self
        ])
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [configuration]
            )
            let context = container.mainContext

            let rapide = Tag(nom: "Rapide", couleurHex: "#FF9500")
            let vegetarien = Tag(nom: "Végétarien", couleurHex: "#34C759")
            let tomates = Produit(nom: "Tomates", tags: [vegetarien])
            let pates = Produit(nom: "Pâtes")
            let huile = Produit(nom: "Huile d'olive")
            let yaourt = Produit(nom: "Yaourt nature")
            let oignon = Produit(nom: "Oignon")
            let ail = Produit(nom: "Ail")

            let patesTomate = Recette(
                nom: "Pâtes à la tomate",
                nombreDeParts: 4,
                saisons: [.ete],
                tags: [rapide, vegetarien],
                tempsPreparationMinutes: 20
            )
            let salade = Recette(
                nom: "Salade fraîche",
                nombreDeParts: 2,
                saisons: [.printemps, .ete],
                tags: [vegetarien],
                tempsPreparationMinutes: 10
            )

            let ingredientsPates = [
                IngredientRecette(recette: patesTomate, produit: tomates, quantite: 4),
                IngredientRecette(recette: patesTomate, produit: pates, quantite: 300),
                IngredientRecette(recette: patesTomate, produit: huile, quantite: 2)
            ]
            patesTomate.ingredients = ingredientsPates
            let ingredientSalade = IngredientRecette(
                recette: salade,
                produit: tomates,
                quantite: 2
            )
            salade.ingredients = [ingredientSalade]

            let semaine = Semaine(date: .now)
            let planificationPates = RecetteSemaine(
                recette: patesTomate,
                nombreDeParts: 4
            )
            let planificationSalade = RecetteSemaine(
                recette: salade,
                nombreDeParts: 2
            )
            planificationPates.semaine = semaine
            planificationSalade.semaine = semaine
            semaine.recettes = [planificationPates, planificationSalade]

            let course = Course(semaine: semaine)
            let ingredientCourse = IngredientCourse(
                course: course,
                produit: huile,
                quantite: 1
            )
            course.ingredients = [ingredientCourse]

            [rapide, vegetarien].forEach(context.insert)
            [tomates, pates, huile, yaourt, oignon, ail].forEach(context.insert)
            [patesTomate, salade].forEach(context.insert)
            ingredientsPates.forEach(context.insert)
            context.insert(ingredientSalade)
            context.insert(semaine)
            [planificationPates, planificationSalade].forEach(context.insert)
            context.insert(course)
            context.insert(ingredientCourse)
            try context.save()

            return container
        } catch {
            fatalError("Impossible de créer les données du Canvas : \(error)")
        }
    }
}

/// Adaptateur permettant au preview de CourseListView de recevoir une Course attachée.
struct PreviewCourseView: View {
    @Query private var courses: [Course]

    var body: some View {
        Group {
            if let course = courses.first {
                CourseListView(course: course)
            } else {
                ContentUnavailableView("Aucune course", systemImage: "cart")
            }
        }
    }
}
