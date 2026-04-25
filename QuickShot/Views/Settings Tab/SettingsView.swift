import Foundation
import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("useSelectionOrder") private var useSelectionOrder = false
    @AppStorage("showsDocumentsTab") private var showsDocumentsTab = false
    private let appVersion = Bundle.main.appVersionDisplayString
    private let documentsCacheKey = "documentsLibraryScanCache"
    @State private var isShowingPrivacyPolicy = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    sectionHeader(
                        title: "Conversion",
                        subtitle: "Control how selected photos are ordered in generated PDFs."
                    )
                    settingsCard {
                        Toggle(isOn: $useSelectionOrder) {
                            rowLabel(
                                title: "Use Selection Order",
                                subtitle: "When off, page order follows the photo library.",
                                iconName: "arrow.up.arrow.down"
                            )
                        }
                        .tint(.blue)
                    }

                    sectionHeader(
                        title: "Library",
                        subtitle: "Manage document detection and browsing behavior."
                    )
                    settingsCard {
                        Toggle(isOn: $showsDocumentsTab) {
                            rowLabel(
                                title: "Show Documents Tab",
                                subtitle: "Can use extra power and may detect some non-doc images.",
                                iconName: "doc.text.image"
                            )
                        }
                        .tint(.blue)
                    }

                    sectionHeader(
                        title: "Storage",
                        subtitle: "Local cache directories, temporary files, and scan results."
                    )
                    settingsCard {
                        HStack(spacing: 12) {
                            iconBadge(systemName: "internaldrive")
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Cache")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Current space used by cached app data.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(totalCacheSize)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                    }

                    sectionHeader(
                        title: "About",
                        subtitle: "Version information and legal documents."
                    )
                    settingsCard(spacing: 0) {
                        detailRow(title: "Version", value: appVersion, iconName: "info.circle")
                        Divider()
                            .padding(.leading, 52)
                        Button {
                            isShowingPrivacyPolicy = true
                        } label: {
                            HStack(spacing: 12) {
                                iconBadge(systemName: "hand.raised")
                                Text("Privacy Policy")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 24)
            }
            .background(backgroundView.ignoresSafeArea())
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $isShowingPrivacyPolicy) {
                PrivacyPolicyView()
            }
        }
    }

    private var backgroundView: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.08, green: 0.10, blue: 0.14),
                    Color(red: 0.10, green: 0.08, blue: 0.12),
                    Color(red: 0.06, green: 0.10, blue: 0.11)
                ]
                : [
                    Color(red: 0.95, green: 0.97, blue: 1.0),
                    Color(red: 0.98, green: 0.96, blue: 0.94),
                    Color(red: 0.94, green: 0.97, blue: 0.95)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func rowLabel(title: String, subtitle: String, iconName: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(systemName: iconName)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String, iconName: String) -> some View {
        HStack(spacing: 12) {
            iconBadge(systemName: iconName)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func settingsCard<Content: View>(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: spacing) {
            content()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(cardStroke, lineWidth: 1)
        )
        .shadow(color: cardShadow, radius: 14, x: 0, y: 8)
    }

    private func iconBadge(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.blue)
            .frame(width: 32, height: 32)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.blue.opacity(colorScheme == .dark ? 0.22 : 0.12))
            )
    }

    private var cardBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.90)
    }

    private var cardStroke: Color {
        colorScheme == .dark ? Color.white.opacity(0.14) : Color.white.opacity(0.75)
    }

    private var cardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.30) : Color.black.opacity(0.08)
    }

    private var totalCacheSize: String {
        let cacheSize = directorySize(at: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first)
        let temporarySize = directorySize(at: FileManager.default.temporaryDirectory)
        let documentsScanCacheSize = UserDefaults.standard.data(forKey: documentsCacheKey)?.count ?? 0
        let totalSize = cacheSize + temporarySize + documentsScanCacheSize

        return ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
    }

    private func directorySize(at url: URL?) -> Int {
        guard let url else { return 0 }

        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .fileSizeKey]
        let urls = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsHiddenFiles]
        )?.allObjects as? [URL] ?? []

        return urls.reduce(into: 0) { partialResult, fileURL in
            let values = try? fileURL.resourceValues(forKeys: resourceKeys)
            guard values?.isDirectory != true else { return }
            partialResult += values?.fileSize ?? 0
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

        If you enable the Documents tab, QuickShot can perform a manual on-device scan of your photo library to identify document-looking images. Scan results are cached locally on your device so previously found matches can be shown again after you reopen the app, and refresh scans check only newly added images.

        QuickShot does not require an account and does not collect or sell personal information. If you share a generated PDF, the destination and any further handling are controlled by the share target you choose.

        You can manage photo access in the system Settings app and delete generated PDFs from within QuickShot at any time.
        """
}
