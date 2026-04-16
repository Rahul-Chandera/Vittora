import SwiftUI

enum LegalDocument: String, CaseIterable, Sendable {
    case privacyPolicy = "PrivacyPolicy"
    case termsOfService = "TermsOfService"

    var title: String {
        switch self {
        case .privacyPolicy:
            String(localized: "Privacy Policy")
        case .termsOfService:
            String(localized: "Terms of Service")
        }
    }
}

struct LegalDocumentView: View {
    let document: LegalDocument

    @State private var content: AttributedString?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let content {
                ScrollView {
                    Text(content)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(VSpacing.screenPadding)
                        .textSelection(.enabled)
                }
                .background(VColors.background)
            } else if let errorMessage {
                ContentUnavailableView(
                    String(localized: "Legal Document Unavailable"),
                    systemImage: "doc.text.magnifyingglass",
                    description: Text(errorMessage)
                )
            } else {
                ProgressView()
                    .tint(VColors.primary)
            }
        }
        .navigationTitle(document.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .task {
            if content == nil, errorMessage == nil {
                loadDocument()
            }
        }
    }

    private func loadDocument() {
        do {
            let url = try resolveDocumentURL()
            let markdown = try String(contentsOf: url, encoding: .utf8)

            do {
                content = try AttributedString(
                    markdown: markdown,
                    options: AttributedString.MarkdownParsingOptions(
                        interpretedSyntax: .full,
                        failurePolicy: .returnPartiallyParsedIfPossible
                    )
                )
            } catch {
                content = AttributedString(markdown)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func resolveDocumentURL() throws -> URL {
        let candidateSubdirectories: [String?] = [
            "Resources/Legal",
            "Legal",
            nil,
        ]

        for subdirectory in candidateSubdirectories {
            if let url = Bundle.main.url(
                forResource: document.rawValue,
                withExtension: "md",
                subdirectory: subdirectory
            ) {
                return url
            }
        }

        throw VittoraError.notFound(
            String(localized: "We couldn't load this document from the app bundle.")
        )
    }
}
