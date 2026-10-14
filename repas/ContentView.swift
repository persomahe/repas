//
//  ContentView.swift
//  repas
//
//  Created by celine mahe on 29/08/2026.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    /// Toutes les semaines, triées de la plus récente à la plus ancienne
    @Query(sort: \Semaine.date, order: .reverse) private var semaines: [Semaine]
    @State private var afficherInformations = false
    @State private var fichierAPartager: URL?
    @State private var messageExport: String?
    @State private var messageExportApresPartage: String?

    @State private var fichierAImporter: URL?
    @State private var afficherImport = false
    @State private var afficherConflitDate = false
    @State private var messageImport: String?

    /// La dernière semaine (la plus récente), si elle existe
    private var derniereSemaine: Semaine? {
        semaines.first
    }

    private var exportEstDisponible: Bool {
        guard let semaine = derniereSemaine else { return false }
        return semaineCourse(semaine) != nil
    }

    private var messageExportIndisponible: String {
        guard let semaine = derniereSemaine else {
            return "Planifiez une semaine pour pouvoir l’exporter."
        }
        return semaineCourse(semaine) == nil
            ? "Ouvrez d’abord la liste de courses de la dernière semaine pour la créer, puis revenez ici pour l’exporter."
            : ""
    }

    private func semaineCourse(_ semaine: Semaine) -> Course? {
        (try? modelContext.fetch(FetchDescriptor<Course>()))?.first {
            $0.semaine?.persistentModelID == semaine.persistentModelID
        }
    }

    private func exporterDerniereSemaine() {
        do {
            fichierAPartager = try SemaineExportService.creerFichier(dans: modelContext)
            messageExport = nil
            messageExportApresPartage = "Export terminé."
        } catch {
            messageExportApresPartage = nil
            messageExport = error.localizedDescription
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                FondPageBackground()
                VStack(spacing: 16) {
                    Spacer()

                    NavigationLink("Planifier ma semaine") {
                        SemaineListView()
                    }
                    .buttonStyle(CarteButtonStyle(couleur: Color(hex: "#C2360B")))

                    NavigationLink("Ma liste de courses") {
                        if let semaine = derniereSemaine {
                            CourseDestinationView(semaine: semaine)
                        } else {
                            Text("Aucune semaine planifiée.")
                        }
                    }
                    .buttonStyle(CarteButtonStyle(couleur: Color(hex: "#F17D58")))

                    Image(systemName: "basket.fill")
                        .font(.system(size: 70))
                        .foregroundStyle(Color(hex: "#C3360B"))
                        .padding(.vertical, 40)

                    NavigationLink("Voir les recettes") {
                        RecetteListView()
                    }
                    .buttonStyle(CarteButtonStyle(couleur: .orange))
                    .padding(.bottom, 44)


                    NavigationLink {
                        PartageView(
                            exportEstDisponible: exportEstDisponible,
                            messageExportIndisponible: messageExportIndisponible,
                            messageImport: $messageImport,
                            messageExport: $messageExport,
                            messageExportApresPartage: $messageExportApresPartage,
                            fichierAPartager: $fichierAPartager,
                            afficherConflitDate: $afficherConflitDate,

                            exporter: exporterDerniereSemaine,

                            importer: { afficherImport = true },
                            remplacerImport: {
                                if let url = fichierAImporter {
                                    importer(url: url, remplacerSemaineDeMemeDate: true)
                                }
                            }

                        )
                    } label: {
                        Label("Import / Export", systemImage: "arrow.up.arrow.down")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 0.922, green: 0.651, blue: 0.294))

                    if !exportEstDisponible {
                        Text(messageExportIndisponible)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }

                    NavigationLink("Voir les tags") {
                        TagListView()
                    }
                    .foregroundStyle(.white)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)

                    NavigationLink("Voir les produits") {
                        ProduitListView()
                    }
                    .foregroundStyle(.white)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(hex: "#B3462A"))

                    Spacer()
                }
                .padding(.horizontal)
                .safeAreaPadding(.bottom)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        afficherInformations = true
                    } label: {
                        Image(systemName: "questionmark.circle")
                            .foregroundStyle(Color(hex: "#B3462A"))

                    }
                    .accessibilityLabel("Afficher les informations")
                }
            }
            .sheet(isPresented: $afficherInformations) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("A faire avant toutes choses")
                                .font(.headline)
                            Text("""
                            - Définir les tags.
                            - Définir vos produits.
                            - Créer vos recettes en cliquant sur le bouton orange.\n
                            """)
                            Text("Ordre des opérations pour une liste de courses")
                                .font(.headline)
                            Text("""
                            - Planifiez votre semaine : bouton rouge.
                            - Puis votre liste de courses :
                            Elle héritera des ingrédients des recettes planifiées pour la semaine, auxquels vous pourrez ajouter des produits supplémentaires.
                            """)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                    .navigationTitle("Informations")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Fermer") {
                                afficherInformations = false
                            }
                        }
                    }
                    .tint(.orange)
                }
            }
            .fileImporter(
                isPresented: $afficherImport,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    fichierAImporter = url
                    importer(url: url, remplacerSemaineDeMemeDate: false)
                case .failure(let error):
                    messageImport = error.localizedDescription
                }
            }
        }
        
    }
    
    private func importer(url: URL, remplacerSemaineDeMemeDate: Bool) {
        do {
            try SemaineImportService.importer(
                depuis: url,
                dans: modelContext,
                remplacerSemaineDeMemeDate: remplacerSemaineDeMemeDate
            )
            fichierAImporter = nil
            messageImport = "La semaine et la liste de courses ont été importées."
        } catch let error as SemaineImportService.ImportError {
            if case .conflitDate = error {
                afficherConflitDate = true
            } else {
                messageImport = error.localizedDescription
            }
        } catch {
            messageImport = error.localizedDescription
        }
    }
}

// Arrière-plan partagé utilisé par toutes les vues de l'application.
struct FondPageBackground: View {
    var body: some View {
        GeometryReader { geometry in
            Image("fondPage")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
//                .offset(y: -70)
                .clipped()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// Création d'un style de bouton personnalisé pour les cartes
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
    @State private var preparationEnCours = false
    @State private var erreurPreparation: String?

    init(semaine: Semaine) {
        self.semaine = semaine
        _courses = Query()
    }

    var body: some View {
        Group {
            if let course {
                CourseListView(course: course)
            } else {
                ProgressView("Préparation de la liste...")
            }
        }
        .task { @MainActor in
            guard !preparationEnCours, course == nil else { return }
            preparationEnCours = true
            defer { preparationEnCours = false }

            do {
                let coursesDisponibles = try modelContext.fetch(
                    FetchDescriptor<Course>()
                )
                let semainesDisponibles = try modelContext.fetch(
                    FetchDescriptor<Semaine>()
                )
                let datesParSemaineID: [PersistentIdentifier: Date] =
                    Dictionary(uniqueKeysWithValues: semainesDisponibles.map {
                        ($0.persistentModelID, $0.date)
                    })
                let semaineID = semaine.persistentModelID

                guard let dateSemaine = datesParSemaineID[semaineID] else {
                    throw NSError(
                        domain: "CourseDestinationView",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "La semaine sélectionnée est introuvable."]
                    )
                }

                if let existante = coursesDisponibles.first(where: {
                    $0.semaine?.persistentModelID == semaineID
                }) {
                    course = existante
                    return
                }

                let ancienneCourse = coursesDisponibles
                    .compactMap { candidate -> (course: Course, date: Date)? in
                        guard let candidateSemaineID = candidate.semaine?.persistentModelID,
                              let candidateDate = datesParSemaineID[candidateSemaineID],
                              candidateDate < dateSemaine else {
                            return nil
                        }
                        return (course: candidate, date: candidateDate)
                    }
                    .max { gauche, droite in
                        gauche.date < droite.date
                    }?
                    .course

                let nouvelleCourse = Course(semaine: semaine)
                modelContext.insert(nouvelleCourse)

                if let ancienneCourse {
                    nouvelleCourse.transfererQuantitesManuellesDepuis(ancienneCourse, dans: modelContext)
                }

                nouvelleCourse.materialiserIngredientsHerites(dans: modelContext)
                nouvelleCourse.ingredients.forEach { $0.mettreAJourQuantite() }

                try modelContext.save()
                course = nouvelleCourse
            } catch {
                erreurPreparation = String(describing: error)
                print("Erreur préparation course: \(String(reflecting: error))")
            }
        }
        .alert("Impossible d’ouvrir la liste de courses", isPresented: Binding(
            get: { erreurPreparation != nil },
            set: { if !$0 { erreurPreparation = nil } }
        )) {
            Button("OK", role: .cancel) { erreurPreparation = nil }
        } message: {
            Text(erreurPreparation ?? "Une erreur est survenue.")
        }
    }
}

// Supprimer l’extension Color locale : init(hex:) est déjà définie dans TagListView.swift.

#Preview {
    ContentView()
        .modelContainer(PreviewData.container())
}
private struct PartageView: View {
    let exportEstDisponible: Bool
    let messageExportIndisponible: String
    @Binding var messageImport: String?
    @Binding var messageExport: String?
    @Binding var messageExportApresPartage: String?
    @Binding var fichierAPartager: URL?
    @Binding var afficherConflitDate: Bool
    let exporter: () -> Void
    let importer: () -> Void
    let remplacerImport: () -> Void

    @State private var afficherExportTermine = false

    var body: some View {
        ZStack {
            FondPageBackground()
            VStack(spacing: 20) {
                Button(action: exporter) {
                    Label("Partager mes courses", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!exportEstDisponible)

                if !exportEstDisponible {
                    Text(messageExportIndisponible)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Button(action: importer) {
                    Label("Importer une semaine", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .navigationTitle("Partage")
        .sheet(
            isPresented: Binding(
                get: { fichierAPartager != nil },
                set: { if !$0 { fichierAPartager = nil } }
            ),
            onDismiss: {
                if messageExportApresPartage != nil {
                    messageExportApresPartage = nil
                    afficherExportTermine = true
                }
            }
        ) {
            if let url = fichierAPartager {
                ActivityView(activityItems: [url])
                    .presentationDetents([.medium])
            }
        }
        .alert("Import terminé", isPresented: Binding(
            get: { messageImport != nil && !afficherConflitDate },
            set: { if !$0 { messageImport = nil } }
        )) {
            Button("OK", role: .cancel) { messageImport = nil }
        } message: {
            Text(messageImport ?? "")
        }
        .alert("Export terminé", isPresented: Binding(
            get: { messageExport != nil },
            set: { if !$0 { messageExport = nil } }
        )) {
            Button("OK", role: .cancel) { messageExport = nil }
        } message: {
            Text(messageExport ?? "")
        }
        .alert("Une semaine existe déjà à cette date.", isPresented: $afficherConflitDate) {
            Button("Remplacer", role: .destructive) {
                remplacerImport()
            }
            Button("Annuler", role: .cancel) {
                afficherConflitDate = false
            }
        } message: {
            Text("Voulez-vous la remplacer ?")
        }
        .alert("Export terminé", isPresented: $afficherExportTermine) {
            Button("OK") {
                afficherExportTermine = false
            }
        } message: {
            Text("Vos courses ont été partagées avec succès.")
        }
    }
}
