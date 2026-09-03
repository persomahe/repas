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

    private func dateEnFrancais(_ date: Date) -> String {
        let dateFormatee = date.formatted(
            .dateTime
                .locale(Locale(identifier: "fr_FR"))
                .weekday(.wide)
                .day()
                .month(.abbreviated)
        )

        return dateFormatee.prefix(1).uppercased() + dateFormatee.dropFirst()
    }

    /// Récupère automatiquement toutes les semaines, de la plus récente à la plus ancienne
    @Query(sort: \Semaine.date, order: .reverse) private var semaines: [Semaine]

    /// Contrôle l'affichage de la fiche de planification
    @State private var planificationEnCours = false

    /// Semaine sélectionnée pour consultation / modification.
    @State private var semaineAEditer: Semaine?

    /// Semaine sélectionnée pour suppression (avec confirmation).
    @State private var semaineASupprimer: Semaine?

    var body: some View {
        ZStack(alignment: .top) {
                Color(hex: "#FEF6E7")
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(
                            width: geometry.size.width * 1.4,
                            height: 280
                        )
                        .offset(
                            x: -geometry.size.width * 0.2,
                            y: -36
                        )
                }
                .ignoresSafeArea()
                List {
                ForEach(semaines) { semaine in
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                // Date de la semaine
                                Label(dateEnFrancais(semaine.date), systemImage: "calendar")
                                    .font(.headline)
                                Spacer()

                                Button {
                                    semaineAEditer = semaine
                                } label: {
                                    Image(systemName: "pencil")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Modifier la semaine du \(dateEnFrancais(semaine.date))")

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
                            Label("\(semaine.nombreTotalDeParts) parts totales à préparer", systemImage: "person.2")
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
                                }
                            }
                        }
                        .foregroundStyle(Color(hex: "#AF52DE"))
                        .fontWeight(.medium)
                        
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#F5EAFB").ignoresSafeArea())
        .navigationTitle("Mes semaines")
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
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 42))
                        .foregroundStyle(Color(hex: "#AF52DE"))
                }
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
        return "La semaine du \(dateEnFrancais(date)) sera supprimée définitivement."
    }
}

/// Fiche de planification d'une nouvelle semaine : choix de la date et des recettes avec leurs parts.
struct NouvelleSemaineView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Toutes les recettes existantes, pour la sélection
    @Query(sort: \Recette.nom) private var toutesLesRecettes: [Recette]
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]

    @State private var date = Date()
    @State private var recettesChoisies: [Recette: Int] = [:]

    /// Recette sélectionnée à ajouter à la semaine.
    @State private var recetteChoisie: Recette?

    /// Nombre de parts de la nouvelle recette.
    @State private var nombreDePartsChoisi = 1
    @State private var afficherSelectionRecette = false
    @State private var rechercheRecette = ""

    private var recettesParTag: [(tag: Tag?, recettes: [Recette])] {
        var groupes = tousLesTags.compactMap { tag -> (tag: Tag?, recettes: [Recette])? in
            let recettes = toutesLesRecettes.filter { recette in
                recette.tags.contains { $0.persistentModelID == tag.persistentModelID }
            }
            return recettes.isEmpty ? nil : (tag: tag, recettes: recettes)
        }

        let recettesSansTag = toutesLesRecettes.filter { $0.tags.isEmpty }
        if !recettesSansTag.isEmpty {
            groupes.append((tag: nil, recettes: recettesSansTag))
        }
        return groupes
    }

    private var recettesParTagFiltrees: [(tag: Tag?, recettes: [Recette])] {
        let recherche = rechercheRecette.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recherche.isEmpty else { return recettesParTag }
        return recettesParTag.compactMap { groupe in
            let recettes = groupe.recettes.filter { recette in
                recette.nom.localizedCaseInsensitiveContains(recherche)
                || recette.ingredients.contains {
                    $0.produit?.nom.localizedCaseInsensitiveContains(recherche) == true
                }
            }
            return recettes.isEmpty ? nil : (tag: groupe.tag, recettes: recettes)
        }
    }

    private var recettesSelectionnees: [Recette] {
        toutesLesRecettes.filter { recette in
            (recettesChoisies[recette] ?? 0) > 0
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Date de la semaine") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                }

                Section("Recettes") {
                    ForEach(recettesSelectionnees) { recette in
                        HStack {
                            Text(recette.nom)
                                .foregroundStyle(Color(hex: "#AF52DE"))
                                .fontWeight(.medium)
                            Spacer()
                            Stepper(
                                "\(recettesChoisies[recette] ?? 0) parts",
                                value: Binding(
                                    get: { recettesChoisies[recette] ?? 1 },
                                    set: { recettesChoisies[recette] = $0 }
                                ),
                                in: 1...50
                            )

                            Button {
                                recettesChoisies[recette] = nil
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .accessibilityLabel("Retirer \(recette.nom) de la semaine")
                        }
                    }

                    if toutesLesRecettes.isEmpty {
                        Text("Aucune recette disponible. Crée d'abord des recettes.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Recette")
                            Spacer()
                            Button {
                                afficherSelectionRecette = true
                            } label: {
                                Text(recetteChoisie?.nom ?? "À choisir…")
                                    .foregroundStyle(recetteChoisie == nil ? Color.secondary : Color.purple)
                            }
                        }

                        HStack {
                            Text("Nombre de parts")
                            Spacer()
                            Stepper(
                                "\(nombreDePartsChoisi)",
                                value: $nombreDePartsChoisi,
                                in: 1...50
                            )
                        }

                        Button("Ajouter la recette", systemImage: "plus.circle") {
                            if let recette = recetteChoisie {
                                recettesChoisies[recette] = nombreDePartsChoisi
                                recetteChoisie = nil
                                nombreDePartsChoisi = 1
                            }
                        }
                        .disabled(recetteChoisie == nil)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#F5EAFB").ignoresSafeArea())
            .font(.subheadline)
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
            .sheet(isPresented: $afficherSelectionRecette) {
                NavigationStack {
                    List {
                        ForEach(recettesParTagFiltrees.indices, id: \.self) { index in
                            let groupe = recettesParTagFiltrees[index]
                            DisclosureGroup {
                                ForEach(groupe.recettes) { recette in
                                    Button {
                                        recetteChoisie = recette
                                        afficherSelectionRecette = false
                                    } label: {
                                        HStack {
                                            Text(recette.nom)
                                            Spacer()
                                            if recetteChoisie?.persistentModelID == recette.persistentModelID {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.purple)
                                            }
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            } label: {
                                HStack {
                                    if let tag = groupe.tag {
                                        Circle()
                                            .fill(Color(hex: tag.couleurHex))
                                            .frame(width: 10, height: 10)
                                        Text(tag.nom)
                                    } else {
                                        Image(systemName: "tag.slash")
                                            .foregroundStyle(.secondary)
                                        Text("Sans tag")
                                    }
                                    Spacer()
                                    Text("\(groupe.recettes.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Choisir une recette")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") {
                                afficherSelectionRecette = false
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        TextField("Rechercher une recette", text: $rechercheRecette)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.thinMaterial)
                    }
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
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]

    @State private var date: Date

    /// Recettes planifiées en cours de modification : recette et nombre de parts
    @State private var recettesChoisies: [(recette: Recette, nombreDeParts: Int)]

    /// Saisie de la recette à ajouter
    @State private var recetteChoisie: Recette?
    @State private var nombreDePartsChoisi = 1
    @State private var afficherSelectionRecette = false
    @State private var rechercheRecette = ""

    private var recettesParTag: [(tag: Tag?, recettes: [Recette])] {
        var groupes = tousLesTags.compactMap { tag -> (tag: Tag?, recettes: [Recette])? in
            let recettes = toutesLesRecettes.filter { recette in
                recette.tags.contains { $0.persistentModelID == tag.persistentModelID }
            }
            return recettes.isEmpty ? nil : (tag: tag, recettes: recettes)
        }

        let recettesSansTag = toutesLesRecettes.filter { $0.tags.isEmpty }
        if !recettesSansTag.isEmpty {
            groupes.append((tag: nil, recettes: recettesSansTag))
        }
        return groupes
    }

    private var recettesParTagFiltrees: [(tag: Tag?, recettes: [Recette])] {
        let recherche = rechercheRecette.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recherche.isEmpty else { return recettesParTag }
        return recettesParTag.compactMap { groupe in
            let recettes = groupe.recettes.filter { recette in
                recette.nom.localizedCaseInsensitiveContains(recherche)
                || recette.ingredients.contains {
                    $0.produit?.nom.localizedCaseInsensitiveContains(recherche) == true
                }
            }
            return recettes.isEmpty ? nil : (tag: groupe.tag, recettes: recettes)
        }
    }

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
                            .foregroundStyle(Color(hex: "#AF52DE"))
                            .fontWeight(.medium)
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
                        HStack {
                            Text("Recette")
                            Spacer()
                            Button {
                                afficherSelectionRecette = true
                            } label: {
                                Text(recetteChoisie?.nom ?? "À choisir…")
                                    .foregroundStyle(recetteChoisie == nil ? Color.secondary : Color.purple)
                            }
                        }

                        HStack {
                            Text("Nombre de parts")
                            Spacer()
                            Stepper(
                                "\(nombreDePartsChoisi)",
                                value: $nombreDePartsChoisi,
                                in: 1...50
                            )
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
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#F5EAFB").ignoresSafeArea())
            .font(.subheadline)
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
            .sheet(isPresented: $afficherSelectionRecette) {
                NavigationStack {
                    List {
                        ForEach(recettesParTagFiltrees.indices, id: \.self) { index in
                            let groupe = recettesParTagFiltrees[index]
                            DisclosureGroup {
                                ForEach(groupe.recettes) { recette in
                                    Button {
                                        recetteChoisie = recette
                                        afficherSelectionRecette = false
                                    } label: {
                                        HStack {
                                            Text(recette.nom)
                                            Spacer()
                                            if recetteChoisie?.persistentModelID == recette.persistentModelID {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.purple)
                                            }
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            } label: {
                                HStack {
                                    if let tag = groupe.tag {
                                        Circle()
                                            .fill(Color(hex: tag.couleurHex))
                                            .frame(width: 10, height: 10)
                                        Text(tag.nom)
                                    } else {
                                        Image(systemName: "tag.slash")
                                            .foregroundStyle(.secondary)
                                        Text("Sans tag")
                                    }
                                    Spacer()
                                    Text("\(groupe.recettes.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Choisir une recette")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") {
                                afficherSelectionRecette = false
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        TextField("Rechercher une recette", text: $rechercheRecette)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.thinMaterial)
                    }
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
