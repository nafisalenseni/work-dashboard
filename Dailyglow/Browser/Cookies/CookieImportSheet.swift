import Foundation
import SwiftUI

struct CookieImportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var cookieText = ""
    @State private var errorMessage: String?

    let defaultDomain: String
    let secureByDefault: Bool
    let onImport: ([HTTPCookie]) -> Void

    init(
        defaultDomain: String = "github.com",
        secureByDefault: Bool = true,
        onImport: @escaping ([HTTPCookie]) -> Void
    ) {
        self.defaultDomain = defaultDomain
        self.secureByDefault = secureByDefault
        self.onImport = onImport
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Import Cookies")
                .font(.title2.weight(.semibold))

            Text("Paste exported cookie JSON, rows copied from a browser cookie table, or a Cookie header containing name=value pairs. Cookies without a domain use \(defaultDomain). Cookies with expiration dates persist until they expire; session cookies last until Dailyglow quits.")
                .foregroundStyle(.secondary)

            TextEditor(text: $cookieText)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 240)
                .padding(6)
                .background(.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.separator)
                }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            HStack {
                Spacer()

                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Import") {
                    importCookies()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(
                    cookieText.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
        }
        .padding(24)
        .frame(minWidth: 560, minHeight: 400)
    }

    private func importCookies() {
        do {
            let cookies = try CookieImporter.cookies(
                from: cookieText,
                defaultDomain: defaultDomain,
                secureByDefault: secureByDefault
            )
            onImport(cookies)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#if DEBUG
#Preview("Cookie Import") {
    CookieImportSheet(onImport: { _ in })
}
#endif
