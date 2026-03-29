import SwiftUI

struct SettingsView: View {
    @AppStorage("useSelectionOrder") private var useSelectionOrder = false
    @AppStorage("showsDocumentsTab") private var showsDocumentsTab = false
    private let appVersion = Bundle.main.appVersionDisplayString
    @State private var isShowingPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use Selection Order", isOn: $useSelectionOrder)
                } header: {
                    Text("Conversion")
                } footer: {
                    Text("When off, page order follows the photo library.")
                }

                Section {
                    Toggle("Show Documents Tab", isOn: $showsDocumentsTab)
                } header: {
                    Text("Library")
                } footer: {
                    Text("Adds a Documents tab placeholder for document-focused library browsing. This feature can be power-consuming, may cause your phone to get warm, and might still show some images that do not look like documents.")
                }

                Section("About") {
                    LabeledContent("Version", value: appVersion)
                }

                Section("Legal") {
                    Button("Privacy Policy") {
                        isShowingPrivacyPolicy = true
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $isShowingPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }
}

private struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(policyText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Privacy Policy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    private let policyText =
        """
        QuickShot processes your selected photos on your device to generate PDF files.

        The app requests access to your photo library only so you can choose images to convert. Generated PDFs are saved in your app's Documents folder on your device.

        QuickShot does not require an account and does not collect or sell personal information. If you share a generated PDF, the destination and any further handling are controlled by the share target you choose.

        You can manage photo access in the system Settings app and delete generated PDFs from within QuickShot at any time.
        """
}
