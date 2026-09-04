//
//  RecetteListView.swift
//  repas
//
//  Created by erwan mahe on 29/08/2026.
//

import SwiftUI
import SwiftData

/// Écran affichant la liste des recettes enregistrées dans la base.
struct RecetteListView: View {
    @Environment(\.modelContext) private var context

    /// Récupère automatiquement toutes les recettes, triées par nom
    @Query(sort: \Recette.nom) private var recettes: [Recette]

    /// Tags disponibles pour le filtre.
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]

    @State private var recherche = ""
    @State private var tagSelectionne: Tag?
    @State private var saisonSelectionnee: Saison?

    /// Contrôle l'affichage de la fiche de création d'une recette
    @State private var ajoutEnCours = false

    /// Recette sélectionnée pour consultation / modification.
    @State private var recetteAEditer: Recette?

    /// Recette sélectionnée pour suppression (avec confirmation).
    @State private var recetteASupprimer: Recette?

    @State private var afficherInformations = false

    private var recettesFiltrees: [Recette] {
        recettes.filter { recette in
            let texte = recherche.trimmingCharacters(in: .whitespacesAndNewlines)
            let correspondAuTexte = texte.isEmpty
                || recette.nom.localizedCaseInsensitiveContains(texte)
                || recette.ingredients.contains { ingredient in
                    ingredient.produit?.nom.localizedCaseInsensitiveContains(texte) == true
                }
            let correspondAuTag = tagSelectionne.map { tag in
                recette.tags.contains { $0.persistentModelID == tag.persistentModelID }
            } ?? true
            let correspondALaSaison = saisonSelectionnee.map { saison in
                recette.saisons.contains(saison)
            } ?? true
            return correspondAuTexte && correspondAuTag && correspondALaSaison
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
                Color(hex: "#FEF6E7")
                    .ignoresSafeArea()

                GeometryReader { geometry in
                    Ellipse()
                        .fill(
                            LinearGradient(
                                colors: [.orange, .pink],
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
                ForEach(recettesFiltrees.indices, id: \.self) { index in
                    recetteRow(recettesFiltrees[index])
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color(hex: "#FEF6E7").ignoresSafeArea())
        .searchable(text: $recherche, prompt: "Nom d'une recette ou d'un produit")
        .navigationTitle("Recettes")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Section("Tags") {
                        Button {
                            tagSelectionne = nil
                        } label: {
                            Label("Tous les tags", systemImage: tagSelectionne == nil ? "checkmark" : "tag")
                        }
                        ForEach(tousLesTags) { tag in
                            Button {
                                tagSelectionne = tag
                            } label: {
                                tagFilterLabel(for: tag)
                            }
                        }
                    }
                    Section("Saisons") {
                        Button {
                            saisonSelectionnee = nil
                        } label: {
                            Label("Toutes les saisons", systemImage: saisonSelectionnee == nil ? "checkmark" : "calendar")
                        }
                        ForEach(Saison.allCases) { saison in
                            Button {
                                saisonSelectionnee = saison
                            } label: {
                                saisonFilterLabel(for: saison)
                            }
                        }
                    }
                } label: {
                    let filtreActif = tagSelectionne != nil || saisonSelectionnee != nil
                    Label(
                        "Filtrer",
                        systemImage: filtreActif
                            ? "line.3.horizontal.decrease.circle.fill"
                            : "line.3.horizontal.decrease.circle"
                    )
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button("Ajouter une recette", systemImage: "plus") {
                    ajoutEnCours = true
                }
            }
            
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    afficherInformations = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .accessibilityLabel("Afficher les informations")
            }
        }
        .sheet(isPresented: $ajoutEnCours) {
            NouvelleRecetteView()
        }
        .sheet(item: $recetteAEditer) { recette in
            EditRecetteView(recette: recette)
        }
        .sheet(isPresented: $afficherInformations) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("""
                        - Les recettes ne contiennent que les ingrédients essentiels à la liste de courses : le sel, le poivre, l’ail, la sauce tomate… sont déjà dans les placards !)
                        - Tagger les recettes est important pour pouvoir les filtrer.\n
                        """)

                        Text("Nouvelle recette +")
                            .font(.headline)

                        Text("""
                        - Entrer le nom de la recette.
                        - Cliquer sur Recette\t\tÀ choisir…
                        - Choisir un ingrédient.
                        - Préciser la quantité correspondant au nombre de parts de la recette.
                        - Cliquer sur Ajouter l’ingrédient.
                        - Recommencer pour tous les ingrédients.
                        - Cliquer sur Ajouter pour enregistrer la recette.
                        - Spécifier les tags.\n
                        """)

                        Text("Modifier une recette")
                            .font(.headline)

                        Text("""
                        - Cliquer sur le crayon à droite de la recette.
                        - Modifier les informations souhaitées.
                        - Cliquer sur Enregistrer pour enregistrer les modifications.\n
                        """)

                        Text("Supprimer une recette")
                            .font(.headline)

                        Text("""
                        - Cliquer sur la poubelle à droite de la recette.
                        - Confirmer la suppression.
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
        .confirmationDialog(
            "Supprimer cette recette ?",
            isPresented: suppressionDialogBinding,
            titleVisibility: .visible
        ) {
            Button("Supprimer", role: .destructive) {
                if let recetteASupprimer {
                    context.delete(recetteASupprimer)
                }
                recetteASupprimer = nil
            }
            Button("Annuler", role: .cancel) {
                recetteASupprimer = nil
            }
        } message: {
            Text(suppressionMessage)
        }
        .overlay {
            if recettesFiltrees.isEmpty {
                ContentUnavailableView(
                    recettes.isEmpty ? "Aucune recette" : "Aucun résultat",
                    systemImage: recettes.isEmpty ? "book" : "magnifyingglass",
                    description: Text(recettes.isEmpty ? "Les recettes que tu créeras apparaîtront ici." : "Aucune recette ne correspond aux filtres sélectionnés.")
                )
            }
        }
    }

    @ViewBuilder
    private func recetteRow(_ recette: Recette) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(recette.nom)
                    .font(.headline)
                    .foregroundStyle(.orange)

                HStack(spacing: 12) {
                    Label("\(recette.nombreDeParts) parts", systemImage: "person.2")
                    Label("\(recette.tempsPreparationMinutes) min", systemImage: "clock")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                if !recette.saisons.isEmpty {
                    Text(recette.saisons.map(\.rawValue).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !recette.tags.isEmpty {
                    HStack(spacing: 6) {
                        ForEach(recette.tags) { tag in
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color(hex: tag.couleurHex))
                                    .frame(width: 8, height: 8)
                                Text(tag.nom)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer()

            Button {
                recetteAEditer = recette
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Modifier la recette \(recette.nom)")

            Button {
                recetteASupprimer = recette
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.red)
            .accessibilityLabel(Text("Supprimer la recette"))
        }
    }

    private func tagFilterLabel(for tag: Tag) -> some View {
        let selectionnee = tagSelectionne?.persistentModelID == tag.persistentModelID
        return Label(tag.nom, systemImage: selectionnee ? "checkmark" : "tag")
    }

    private func saisonFilterLabel(for saison: Saison) -> some View {
        let selectionnee = saisonSelectionnee == saison
        return Label(saison.rawValue, systemImage: selectionnee ? "checkmark" : "calendar")
    }

    private var suppressionDialogBinding: Binding<Bool> {
        Binding(
            get: { recetteASupprimer != nil },
            set: { if !$0 { recetteASupprimer = nil } }
        )
    }

    private var suppressionMessage: String {
        guard let nom = recetteASupprimer?.nom, !nom.isEmpty else {
            return "Cette recette sera supprimee definitivement."
        }
        return "La recette \(nom) sera supprimee definitivement."
    }
}

/// Fiche de création d'une nouvelle recette.
struct NouvelleRecetteView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Tags et produits existants, pour les sélections
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]
    @Query(sort: \Produit.nom) private var tousLesProduits: [Produit]

    @State private var nom = ""
    @State private var nombreDeParts = 4
    @State private var saisonsChoisies: Set<Saison> = []
    @State private var tagsChoisis: Set<Tag> = []
    @State private var lienTexte = ""
    @State private var tempsPreparationMinutes = 30

    /// Ingrédients en cours de composition : produit et quantité
    @State private var ingredients: [(produit: Produit, quantite: Double)] = []

    /// Saisie de l'ingrédient à ajouter
    @State private var produitChoisi: Produit?
    @State private var quantiteChoisie = 1.0
    @State private var afficherSelectionProduit = false
    @State private var rechercheProduit = ""

    private var pasDeQuantite: Double {
        produitChoisi?.typeUnite.pas ?? TypeUnite.piece.pas
    }

    private var produitsParTagFiltres: [(tag: Tag?, produits: [Produit])] {
        let recherche = rechercheProduit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recherche.isEmpty else { return produitsParTag }

        return produitsParTag.compactMap { groupe in
            let produits = groupe.produits.filter {
                $0.nom.localizedCaseInsensitiveContains(recherche)
            }
            return produits.isEmpty ? nil : (tag: groupe.tag, produits: produits)
        }
    }

    private var produitsParTag: [(tag: Tag?, produits: [Produit])] {
        var groupes = tousLesTags.compactMap { tag -> (tag: Tag?, produits: [Produit])? in
            let produits = tousLesProduits.filter { produit in
                produit.tags.contains { $0.persistentModelID == tag.persistentModelID }
            }
            return produits.isEmpty ? nil : (tag: tag, produits: produits)
        }
        let produitsSansTag = tousLesProduits.filter { $0.tags.isEmpty }
        if !produitsSansTag.isEmpty {
            groupes.append((tag: nil, produits: produitsSansTag))
        }
        return groupes
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de la recette", text: $nom)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    HStack {
                        Text("Parts")

                        Button {
                            nombreDeParts = max(1, nombreDeParts - 1)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)

                        Text("\(nombreDeParts)")
                            .monospacedDigit()
                            .frame(width: 20)

                        Button {
                            nombreDeParts = min(50, nombreDeParts + 1)
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Text("Préparation (min)")

                        Button {
                            tempsPreparationMinutes = max(0, tempsPreparationMinutes - 5)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)

                        Text("\(tempsPreparationMinutes)")
                            .monospacedDigit()
                            .frame(width: 30)

                        Button {
                            tempsPreparationMinutes = min(600, tempsPreparationMinutes + 5)
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Section("Ingrédients") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 70), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(ingredients.indices, id: \.self) { index in
                            VStack(spacing: 6) {
                                Text(ingredients[index].produit.nom)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                Text(ingredients[index].quantite.formatted())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                    }
                    .padding(.vertical, 8)

                    if tousLesProduits.isEmpty {
                        Text("Aucun produit disponible. Crée d'abord des produits.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Ingrédient à ajouter")
                            Spacer()
                            Button {
                                afficherSelectionProduit = true
                            } label: {
                                Text(produitChoisi?.nom ?? "À choisir…")
                                    .foregroundStyle(produitChoisi == nil ? Color.secondary : Color.orange)
                            }
                        }

                        HStack {
                            Text("Quantité")
                            Spacer()

                            Button {
                                quantiteChoisie = max(pasDeQuantite, quantiteChoisie - pasDeQuantite)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)

                            Text(quantiteChoisie.formatted(.number.precision(.fractionLength(0...2))))
                                .monospacedDigit()
                                .frame(minWidth: 40)

                            Button {
                                quantiteChoisie += pasDeQuantite
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                        }

                        Button("Ajouter l'ingrédient", systemImage: "plus.circle") {
                            if let produit = produitChoisi {
                                ingredients.append((produit: produit, quantite: quantiteChoisie))
                                produitChoisi = nil
                                quantiteChoisie = pasDeQuantite
                            }
                        }
                        .disabled(produitChoisi == nil)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    }
                }

                Section("Lien vers la recette") {
                    TextField("URL ou chemin de fichier", text: $lienTexte)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section("Saisons") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 70), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(Saison.allCases) { saison in
                            let saisonSelectionnee = saisonsChoisies.contains(saison)

                            Button {
                                if saisonSelectionnee {
                                    saisonsChoisies.remove(saison)
                                } else {
                                    saisonsChoisies.insert(saison)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: saisonSelectionnee ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(saisonSelectionnee ? Color.orange : Color.secondary)

                                    Text(saison.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(saisonSelectionnee ? Color.orange.opacity(0.15) : Color(.secondarySystemBackground))
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(saisonSelectionnee ? Color.orange : Color.clear, lineWidth: 1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Tags") {
                    if tousLesTags.isEmpty {
                        Text("Aucun tag disponible.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 90), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(tousLesTags) { tag in
                                let tagSelectionne = tagsChoisis.contains(tag)

                                Button {
                                    if tagSelectionne {
                                        tagsChoisis.remove(tag)
                                    } else {
                                        tagsChoisis.insert(tag)
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: tag.couleurHex))
                                            .frame(width: 24, height: 24)
                                            .overlay {
                                                if tagSelectionne {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                            }

                                        Text(tag.nom)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 70)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                tagSelectionne
                                                ? Color.orange.opacity(0.15)
                                                : Color(.secondarySystemBackground)
                                            )
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                tagSelectionne
                                                ? Color.orange
                                                : Color.clear,
                                                lineWidth: 1
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Nouvelle recette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Ajouter", action: ajouterRecette)
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .font(.subheadline)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#FEF6E7").ignoresSafeArea())
            .sheet(isPresented: $afficherSelectionProduit) {
                NavigationStack {
                    List {
                        ForEach(produitsParTagFiltres.indices, id: \.self) { index in
                            let groupe = produitsParTagFiltres[index]
                            DisclosureGroup {
                                ForEach(groupe.produits) { produit in
                                    Button {
                                        produitChoisi = produit
                                        quantiteChoisie = produit.typeUnite.pas
                                        afficherSelectionProduit = false
                                    } label: {
                                        HStack {
                                            Text(produit.nom)
                                            Spacer()
                                            if produitChoisi?.persistentModelID == produit.persistentModelID {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.orange)
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
                                    Text("\(groupe.produits.count)")
                                    
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Choisir un produit")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") {
                                afficherSelectionProduit = false
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        TextField("Rechercher un produit", text: $rechercheProduit)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.thinMaterial)
                    }
                }
            }

        }
    }

    /// Enregistre la recette et ses ingrédients, puis ferme la fiche.
    private func ajouterRecette() {
        let nomNettoye = nom.trimmingCharacters(in: .whitespaces)
        guard !nomNettoye.isEmpty else { return }

        let lienNettoye = lienTexte.trimmingCharacters(in: .whitespaces)

        let recette = Recette(
            nom: nomNettoye,
            nombreDeParts: nombreDeParts,
            saisons: Array(saisonsChoisies),
            tags: Array(tagsChoisis),
            lien: lienNettoye.isEmpty ? nil : URL(string: lienNettoye),
            tempsPreparationMinutes: tempsPreparationMinutes,
            ingredients: ingredients.map { IngredientRecette(produit: $0.produit, quantite: $0.quantite) }
        )
        context.insert(recette)
        dismiss()
    }
}

/// Fiche de consultation / modification d'une recette existante.
struct EditRecetteView: View {
    let recette: Recette

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// Tags et produits existants, pour les sélections
    @Query(sort: \Tag.nom) private var tousLesTags: [Tag]
    @Query(sort: \Produit.nom) private var tousLesProduits: [Produit]

    @State private var nom: String
    @State private var nombreDeParts: Int
    @State private var saisonsChoisies: Set<Saison>
    @State private var tagsChoisis: Set<Tag>
    @State private var lienTexte: String
    @State private var tempsPreparationMinutes: Int

    /// Ingrédients en cours de composition : produit et quantité
    @State private var ingredients: [(produit: Produit, quantite: Double)]

    /// Saisie de l'ingrédient à ajouter
    @State private var produitChoisi: Produit?
    @State private var quantiteChoisie = 1.0
    @State private var afficherSelectionProduit = false
    @State private var rechercheProduit = ""

    private var pasDeQuantite: Double {
        produitChoisi?.typeUnite.pas ?? TypeUnite.piece.pas
    }

    private var produitsParTagFiltres: [(tag: Tag?, produits: [Produit])] {
        let recherche = rechercheProduit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !recherche.isEmpty else { return produitsParTag }
        return produitsParTag.compactMap { groupe in
            let produits = groupe.produits.filter {
                $0.nom.localizedCaseInsensitiveContains(recherche)
            }
            return produits.isEmpty ? nil : (tag: groupe.tag, produits: produits)
        }
    }

    private var produitsParTag: [(tag: Tag?, produits: [Produit])] {
        var groupes = tousLesTags.compactMap { tag -> (tag: Tag?, produits: [Produit])? in
            let produits = tousLesProduits.filter { produit in
                produit.tags.contains { $0.persistentModelID == tag.persistentModelID }
            }
            return produits.isEmpty ? nil : (tag: tag, produits: produits)
        }
        let produitsSansTag = tousLesProduits.filter { $0.tags.isEmpty }
        if !produitsSansTag.isEmpty {
            groupes.append((tag: nil, produits: produitsSansTag))
        }
        return groupes
    }

    init(recette: Recette) {
        self.recette = recette
        _nom = State(initialValue: recette.nom)
        _nombreDeParts = State(initialValue: recette.nombreDeParts)
        _saisonsChoisies = State(initialValue: Set(recette.saisons))
        _tagsChoisis = State(initialValue: Set(recette.tags))
        _lienTexte = State(initialValue: recette.lien?.absoluteString ?? "")
        _tempsPreparationMinutes = State(initialValue: recette.tempsPreparationMinutes)
        _ingredients = State(initialValue: recette.ingredients.map { (produit: $0.produit!, quantite: $0.quantite) })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nom de la recette", text: $nom)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                    HStack {
                        Text("Parts")

                        Button {
                            nombreDeParts = max(1, nombreDeParts - 1)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.borderless)

                        Text("\(nombreDeParts)")
                            .monospacedDigit()
                            .frame(width: 20)

                        Button {
                            nombreDeParts = min(50, nombreDeParts + 1)
                        } label: {
                            Image(systemName: "plus.circle")
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Text("Préparation (min)")


                         Button {
                             tempsPreparationMinutes = max(0, tempsPreparationMinutes - 5)
                         } label: {
                             Image(systemName: "minus.circle")
                         }
                         .buttonStyle(.borderless)

                         Text("\(tempsPreparationMinutes)")
                             .monospacedDigit()
                             .frame(width: 30)

                         Button {
                             tempsPreparationMinutes = min(600, tempsPreparationMinutes + 5)
                         } label: {
                             Image(systemName: "plus.circle")
                         }
                         .buttonStyle(.borderless)
                     }
                 }

                 Section("Ingrédients") {
                     LazyVGrid(
                         columns: [
                             GridItem(.adaptive(minimum: 70), spacing: 12)
                         ],
                         spacing: 12
                     ) {
                         ForEach(ingredients.indices, id: \.self) { index in
                            VStack(spacing: 6) {
                                Text(ingredients[index].produit.nom)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)

                                Text(ingredients[index].quantite.formatted())
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.orange)
                            }
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                    }
                    .padding(.vertical, 8)

                    if tousLesProduits.isEmpty {
                        Text("Aucun produit disponible. Crée d'abord des produits.")
                            .foregroundStyle(.secondary)
                    } else {
                        HStack {
                            Text("Ingrédient à ajouter")
                            Spacer()
                            Button {
                                afficherSelectionProduit = true
                            } label: {
                                Text(produitChoisi?.nom ?? "À choisir…")
                                    .foregroundStyle(produitChoisi == nil ? Color.secondary : Color.orange)
                            }
                        }

                        HStack {
                            Text("Quantité")
                            Spacer()

                            Button {
                                quantiteChoisie = max(pasDeQuantite, quantiteChoisie - pasDeQuantite)
                            } label: {
                                Image(systemName: "minus.circle")
                            }
                            .buttonStyle(.borderless)

                            Text(quantiteChoisie.formatted(.number.precision(.fractionLength(0...2))))
                                .monospacedDigit()
                                .frame(minWidth: 40)

                            Button {
                                quantiteChoisie += pasDeQuantite
                            } label: {
                                Image(systemName: "plus.circle")
                            }
                            .buttonStyle(.borderless)
                        }

                        Button("Ajouter l'ingrédient", systemImage: "plus.circle") {
                            if let produit = produitChoisi {
                                ingredients.append((produit: produit, quantite: quantiteChoisie))
                                produitChoisi = nil
                                quantiteChoisie = pasDeQuantite
                            }
                        }
                        .disabled(produitChoisi == nil)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                    }
                }
 
                
                Section("Lien vers la recette") {
                    TextField("URL ou chemin de fichier", text: $lienTexte)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                
                Section("Saisons") {
                    LazyVGrid(
                        columns: [
                            GridItem(.adaptive(minimum: 70), spacing: 12)
                        ],
                        spacing: 12
                    ) {
                        ForEach(Saison.allCases) { saison in
                            let saisonSelectionnee = saisonsChoisies.contains(saison)

                            Button {
                                if saisonSelectionnee {
                                    saisonsChoisies.remove(saison)
                                } else {
                                    saisonsChoisies.insert(saison)
                                }
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: saisonSelectionnee ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(saisonSelectionnee ? Color.orange : Color.secondary)

                                    Text(saison.rawValue)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, minHeight: 70)
                                .padding(8)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(
                                            saisonSelectionnee
                                            ? Color.orange.opacity(0.15)
                                            : Color(.secondarySystemBackground)
                                        )
                                )
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            saisonSelectionnee
                                            ? Color.orange
                                            : Color.clear,
                                            lineWidth: 1
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Tags") {
                    if tousLesTags.isEmpty {
                        Text("Aucun tag disponible.")
                            .foregroundStyle(.secondary)
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.adaptive(minimum: 90), spacing: 12)
                            ],
                            spacing: 12
                        ) {
                            ForEach(tousLesTags) { tag in
                                let tagSelectionne = tagsChoisis.contains(tag)

                                Button {
                                    if tagSelectionne {
                                        tagsChoisis.remove(tag)
                                    } else {
                                        tagsChoisis.insert(tag)
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        Circle()
                                            .fill(Color(hex: tag.couleurHex))
                                            .frame(width: 24, height: 24)
                                            .overlay {
                                                if tagSelectionne {
                                                    Image(systemName: "checkmark")
                                                        .font(.caption)
                                                        .fontWeight(.bold)
                                                        .foregroundStyle(.white)
                                                }
                                            }

                                        Text(tag.nom)
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .multilineTextAlignment(.center)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, minHeight: 70)
                                    .padding(8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(
                                                tagSelectionne
                                                ? Color.orange.opacity(0.15)
                                                : Color(.secondarySystemBackground)
                                            )
                                    )
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(
                                                tagSelectionne
                                                ? Color.orange
                                                : Color.clear,
                                                lineWidth: 1
                                            )
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle("Modifier la recette")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer", action: enregistrerRecette)
                        .disabled(nom.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .font(.subheadline)
            .scrollContentBackground(.hidden)
            .background(Color(hex: "#FEF6E7").ignoresSafeArea())
            .sheet(isPresented: $afficherSelectionProduit) {
                NavigationStack {
                    List {
                        ForEach(produitsParTagFiltres.indices, id: \.self) { index in
                            let groupe = produitsParTagFiltres[index]
                            DisclosureGroup {
                                ForEach(groupe.produits) { produit in
                                    Button {
                                        produitChoisi = produit
                                        quantiteChoisie = produit.typeUnite.pas
                                        afficherSelectionProduit = false
                                    } label: {
                                        HStack {
                                            Text(produit.nom)
                                            Spacer()
                                            if produitChoisi?.persistentModelID == produit.persistentModelID {
                                                Image(systemName: "checkmark")
                                                    .foregroundStyle(.orange)
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
                                    Text("\(groupe.produits.count)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Choisir un produit")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Fermer") {
                                afficherSelectionProduit = false
                            }
                        }
                    }
                    .safeAreaInset(edge: .bottom) {
                        TextField("Rechercher un produit", text: $rechercheProduit)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.thinMaterial)
                    }
                }
            }

        }
    }

    /// Enregistre les modifications de la recette, puis ferme la fiche.
    private func enregistrerRecette() {
        let nomNettoye = nom.trimmingCharacters(in: .whitespaces)
        guard !nomNettoye.isEmpty else { return }

        let lienNettoye = lienTexte.trimmingCharacters(in: .whitespaces)

        recette.nom = nomNettoye
        recette.nombreDeParts = nombreDeParts
        recette.saisons = Array(saisonsChoisies)
        recette.tags = Array(tagsChoisis)
        recette.lien = lienNettoye.isEmpty ? nil : URL(string: lienNettoye)
        recette.tempsPreparationMinutes = tempsPreparationMinutes
        recette.ingredients = ingredients.map { ingredient in
            IngredientRecette(
                produit: ingredient.produit,
                quantite: ingredient.quantite
            )
        }
        dismiss()
    }
}

#Preview("Liste des recettes") {
    NavigationStack {
        RecetteListView()
    }
    .modelContainer(PreviewData.container())
}

private struct EditRecettePreviewContainer: View {
    @Query(sort: \Recette.nom) private var recettes: [Recette]

    var body: some View {
        Group {
            if let recette = recettes.first {
                EditRecetteView(recette: recette)
            } else {
                ProgressView("Chargement de la recette…")
            }
        }
    }
}

#Preview("Modifier une recette") {
    NavigationStack {
        EditRecettePreviewContainer()
    }
    .modelContainer(PreviewData.container())
}
