import SwiftUI

struct SettingsView: View {
    @AppStorage("useSelectionOrder") private var useSelectionOrder = false

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
            }
            .navigationTitle("Settings")
        }
    }
}
