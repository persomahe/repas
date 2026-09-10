import SwiftUI
import PDFKit

struct RecipePDFView: View {
    let recipeName: String
    let pageNumber: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            RecipePDFKitView(pageNumber: pageNumber)
                .navigationTitle(recipeName)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fermer") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

private struct RecipePDFKitView: UIViewRepresentable {
    let pageNumber: Int

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .secondarySystemBackground

        guard let url = Bundle.main.url(forResource: "RECETTES", withExtension: "PDF"),
              let document = PDFDocument(url: url),
              let page = document.page(at: max(0, pageNumber - 1)) else {
            return pdfView
        }

        pdfView.document = document
        pdfView.layoutDocumentView()

        DispatchQueue.main.async {
            pdfView.go(to: page)
        }
        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {}
}
