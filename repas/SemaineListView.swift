//
//  SemaineListView.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

/// Écran affichant la planification de la semaine : date, nombre de parts et recettes prévues.
struct SemaineListView: View {
    /// Récupère automatiquement toutes les semaines, triées par date
    @Query(sort: \Semaine.date) private var semaines: [Semaine]

    /// Contrôle l'affichage de la fiche de planification
    @State private var planificationEnCours = false

    var body: some View {
        List(semaines) { semaine in
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    // Date de la semaine
                    Label(semaine.date.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                        .font(.headline)

                    // Nombre total de parts à préparer
                    Label("\(semaine.nombreTotalDeParts) parts à préparer", systemImage: "person.2")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Liste des recettes planifiées
                ForEach(semaine.recettes) { planification in
                    if let recette = planification.recette {
                        HStack {
                            Text(recette.nom)
                            Spacer()
                            Text("\(planification.nombreDeParts) parts")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Ma semaine")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Planifier ma semaine", systemImage: "plus") {
                    planificationEnCours = true
                }
            }
        }
        .sheet(isPresented: $planificationEnCours) {
            NouvelleSemaineView()
        }
        .overlay {
            if semaines.isEmpty {
                ContentUnavailableView(
                    "Aucune semaine planifiée",
                    systemImage: "calendar.badge.plus",
                    description: Text("Planifie ta semaine pour voir ici la date, le nombre de parts et les recettes.")
                )
            }
        }
    }
}

/// Fiche de planification d'une nouvelle semaine : choix de la date et des recettes avec leurs parts.
struct NouvelleSemaineView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Toutes les recettes existantes, pour la sélection
    @Query(sort: \Recette.nom) private var toutesLesRecettes: [Recette]

    @State private var date = Date()
    @State private var recettesChoisies: [Recette: Int] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Date de la semaine") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Recettes") {
                    if toutesLesRecettes.isEmpty {
                        Text("Aucune recette disponible. Crée d'abord des recettes.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(toutesLesRecettes) { recette in
                            HStack {
                                Text(recette.nom)
                                Spacer()
                                Stepper(
                                    "\(recettesChoisies[recette] ?? 0) parts",
                                    value: Binding(
                                        get: { recettesChoisies[recette] ?? 0 },
                                        set: { recettesChoisies[recette] = $0 }
                                    ),
                                    in: 0...50
                                )
                            }
                        }
                    }
                }
            }
            .navigationTitle("Planifier ma semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: enregistrer)
                        .disabled(recettesChoisies.values.allSatisfy { $0 == 0 })
                }
            }
        }
    }

    /// Enregistre la semaine et ses recettes planifiées, puis ferme la fiche.
    private func enregistrer() {
        let planifications = recettesChoisies
            .filter { $0.value > 0 }
            .map { RecetteSemaine(recette: $0.key, nombreDeParts: $0.value) }

        context.insert(Semaine(date: date, recettes: planifications))
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SemaineListView()
    }
    .modelContainer(for: [Tag.self, Produit.self, Recette.self, IngredientRecette.self, Semaine.self, RecetteSemaine.self], inMemory: true)
}
