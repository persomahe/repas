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
            VStack {
                Text("Application REPAS")

                NavigationLink("Voir les tags") {
                    TagListView()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)

                NavigationLink("Voir les produits") {
                    ProduitListView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Voir les recettes") {
                    RecetteListView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Planifier ma semaine") {
                    SemaineListView()
                }
                .buttonStyle(.borderedProminent)

                NavigationLink("Ma liste de courses") {
                    if let semaine = derniereSemaine {
                        CourseDestinationView(semaine: semaine)
                    } else {
                        Text("Aucune semaine planifiée.")
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("REPAS")
        }
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
