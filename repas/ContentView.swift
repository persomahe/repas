//
//  ContentView.swift
//  repas
//
//  Created by celine mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    /// Toutes les semaines, triées de la plus récente à la plus ancienne
    @Query(sort: \Semaine.date, order: .reverse) private var semaines: [Semaine]

    /// La dernière semaine (la plus récente), si elle existe
    private var derniereSemaine: Semaine? {
        semaines.first
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                NavigationLink("Planifier ma semaine") {
                    SemaineListView()
                }
                .buttonStyle(CarteButtonStyle(couleur: .orange))

                NavigationLink("Ma liste de courses") {
                    if let semaine = derniereSemaine {
                        CourseDestinationView(semaine: semaine)
                    } else {
                        Text("Aucune semaine planifiée.")
                    }
                }
                .buttonStyle(CarteButtonStyle(couleur: .green))
                
                Spacer()
                
                NavigationLink("Voir les recettes") {
                    RecetteListView()
                }
                .buttonStyle(CarteButtonStyle(couleur: .purple))

                Spacer()
                
                Text("Paramètres")
                .padding(.top)
                .font(.subheadline)
                .fontWeight(.regular)

                NavigationLink("Voir les tags") {
                    TagListView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)

                NavigationLink("Voir les produits") {
                    ProduitListView()
                }
                .buttonStyle(.borderedProminent)

            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Gestion des repas")
                        .font(.system(size: 36, weight: .bold))
                }
            }
            .fontWeight(.bold)

        }
        
    }
    
}

//Création d'un style de bouton personnalisé pour les cartes
struct CarteButtonStyle: ButtonStyle {
    let couleur: Color
        let couleurAppui: Color

        init(couleur: Color, couleurAppui: Color? = nil) {
            self.couleur = couleur
            self.couleurAppui = couleurAppui ?? couleur.opacity(0.7)
        }
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(
                width: 200,
                height: 60,
                alignment: .center
            )
            .multilineTextAlignment(.center)
            .padding()
            .background(configuration.isPressed ? .gray : couleur)
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .font(.title2)
    }
}


/// Prépare une course gérée par SwiftData pour la semaine puis affiche la liste.
private struct CourseDestinationView: View {
    let semaine: Semaine

    @Environment(\.modelContext) private var modelContext
    @Query private var courses: [Course]
    @State private var course: Course?

    init(semaine: Semaine) {
        self.semaine = semaine
        let semaineID = semaine.persistentModelID
        _courses = Query(filter: #Predicate<Course> { course in
            course.semaine?.persistentModelID == semaineID
        })
    }

    var body: some View {
        Group {
            if let course {
                CourseListView(course: course)
            } else {
                ProgressView("Préparation de la liste...")
            }
        }
        .task {
            if let existante = courses.first {
                course = existante
                return
            }

            let nouvelleCourse = Course(semaine: semaine)
            modelContext.insert(nouvelleCourse)
            course = nouvelleCourse
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(PreviewData.container())
}
