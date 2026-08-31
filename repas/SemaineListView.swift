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
    @Environment(\.modelContext) private var context

    /// Récupère automatiquement toutes les semaines, triées par date
    @Query(sort: \Semaine.date) private var semaines: [Semaine]

    /// Contrôle l'affichage de la fiche de planification
    @State private var planificationEnCours = false

    /// Semaine sélectionnée pour consultation / modification.
    @State private var semaineAEditer: Semaine?

    /// Semaine sélectionnée pour suppression (avec confirmation).
    @State private var semaineASupprimer: Semaine?

    var body: some View {
        List {
            ForEach(semaines) { semaine in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            // Date de la semaine
                            Label(semaine.date.formatted(date: .complete, time: .omitted), systemImage: "calendar")
                                .font(.headline)
                            Spacer()

                            Button {
                                semaineAEditer = semaine
                            } label: {
                                Image(systemName: "pencil")
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Modifier la semaine du \(semaine.date.formatted(date: .abbreviated, time: .omitted))")

                            Button {
                                semaineASupprimer = semaine
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.red)
                            .accessibilityLabel("Supprimer la semaine")
                        }
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

                    // Actions : consultation / modification et suppression

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
        .sheet(item: $semaineAEditer) { semaine in
            EditSemaineView(semaine: semaine)
        }
        .confirmationDialog(
            "Supprimer cette semaine ?",
            isPresented: suppressionDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let semaineASupprimer {
                    context.delete(semaineASupprimer)
                }
                semaineASupprimer = nil
            }
            Button("Annuler", role: .cancel) {
                semaineASupprimer = nil
            }
        } message: {
            Text(suppressionMessage)
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

    private var suppressionDialogBinding: Binding<Bool> {
        Binding(
            get: { semaineASupprimer != nil },
            set: { if !$0 { semaineASupprimer = nil } }
        )
    }

    private var suppressionMessage: String {
        guard let date = semaineASupprimer?.date else {
            return "Cette semaine sera supprimée définitivement."
        }
        return "La semaine du \(date.formatted(date: .complete, time: .omitted)) sera supprimée définitivement."
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

/// Fiche de consultation / modification d'une semaine existante.
struct EditSemaineView: View {
    let semaine: Semaine

    @Environment(\.dismiss) private var dismiss

    /// Toutes les recettes existantes, pour la sélection
    @Query(sort: \Recette.nom) private var toutesLesRecettes: [Recette]

    @State private var date: Date

    /// Recettes planifiées en cours de modification : recette et nombre de parts
    @State private var recettesChoisies: [(recette: Recette, nombreDeParts: Int)]

    /// Saisie de la recette à ajouter
    @State private var recetteChoisie: Recette?
    @State private var nombreDePartsChoisi = 1

    init(semaine: Semaine) {
        self.semaine = semaine
        _date = State(initialValue: semaine.date)
        _recettesChoisies = State(initialValue: semaine.recettes.compactMap { planification in
            guard let recette = planification.recette else { return nil }
            return (recette: recette, nombreDeParts: planification.nombreDeParts)
        })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date de la semaine") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Recettes") {
                    ForEach(recettesChoisies.indices, id: \.self) { index in
                        HStack {
                            Text(recettesChoisies[index].recette.nom)
                            Spacer()
                            Stepper(
                                "\(recettesChoisies[index].nombreDeParts) parts",
                                value: $recettesChoisies[index].nombreDeParts,
                                in: 1...50
                            )

                            // Retire la recette de la semaine (sans la supprimer de la liste des recettes)
                            Button {
                                recettesChoisies.remove(at: index)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(Color.red)
                            .accessibilityLabel("Retirer \(recettesChoisies[index].recette.nom) de la semaine")
                        }
                    }
                    .onDelete { indices in
                        recettesChoisies.remove(atOffsets: indices)
                    }

                    if toutesLesRecettes.isEmpty {
                        Text("Aucune recette disponible. Crée d'abord des recettes.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Recette", selection: $recetteChoisie) {
                            Text("Choisir…").tag(Recette?.none)
                            ForEach(toutesLesRecettes) { recette in
                                Text(recette.nom).tag(Optional(recette))
                            }
                        }

                        HStack {
                            Text("Nombre de parts")
                            Spacer()
                            Stepper("\(nombreDePartsChoisi)", value: $nombreDePartsChoisi, in: 1...50)
                        }

                        Button("Ajouter la recette", systemImage: "plus.circle") {
                            if let recette = recetteChoisie {
                                recettesChoisies.append((recette: recette, nombreDeParts: nombreDePartsChoisi))
                                recetteChoisie = nil
                                nombreDePartsChoisi = 1
                            }
                        }
                        .disabled(recetteChoisie == nil)
                    }
                }
            }
            .navigationTitle("Modifier ma semaine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: enregistrer)
                        .disabled(recettesChoisies.isEmpty)
                }
            }
        }
    }

    /// Enregistre les modifications de la semaine, puis ferme la fiche.
    private func enregistrer() {
        semaine.date = date
        semaine.recettes = recettesChoisies.map { RecetteSemaine(recette: $0.recette, nombreDeParts: $0.nombreDeParts) }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SemaineListView()
    }
    .modelContainer(PreviewData.container())
}
