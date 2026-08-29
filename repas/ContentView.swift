//
//  ContentView.swift
//  repas
//
//  Created by celine mahe on 29/08/2026.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack {
                Image(systemName: "globe")
                    .imageScale(.large)
                    .foregroundStyle(.tint)
                Text("Hello, world!")
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
                
            }
            .padding()
            .navigationTitle("REPAS")
        }
    }
}

#Preview {
    ContentView()
}
