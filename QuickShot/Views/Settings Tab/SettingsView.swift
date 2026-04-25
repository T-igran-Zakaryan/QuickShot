import SwiftUI
import UIKit

struct SettingsView: View {
   @Environment(\.openURL) private var openURL
   @AppStorage("useSelectionOrder") private var useSelectionOrder = false
   @AppStorage("showsDocumentsTab") private var showsDocumentsTab = false
   @AppStorage("prefersDarkMode") private var prefersDarkMode = false
   @AppStorage("appTheme") private var appThemeRawValue = AppTheme.system.rawValue
   private let appVersion = Bundle.main.appVersionDisplayString
   @State private var isShowingPrivacyPolicy = false
   @State private var isShowingFeedbackFallbackAlert = false
   private let feedbackEmailAddress = "octbr27@icloud.com"
   private let feedbackEmailSubject = "QuickShot Feedback"
   private let documentsCacheKey = "documentsLibraryScanCache"
   
   var body: some View {
      NavigationStack {
         Form {
            Section {
               Toggle(isOn: $useSelectionOrder) {
                  Text("Use Selection Order")
                  Text("When off, page order follows the photo library.")
                     .font(.footnote)
               }
               Toggle(isOn: $showsDocumentsTab) {
                  Text("Show Documents Tab")
                  Text("Adds a Documents tab placeholder for document-focused library browsing.")
                     .font(.footnote)
               }
               LabeledContent() {
                  Picker("App Theme", selection: selectedThemeBinding) {
                     ForEach(AppTheme.allCases) { theme in
                        Image(systemName: theme.iconName)
                           .tag(theme)
                     }
                  }
                  .pickerStyle(.segmented)
                  .frame(width: 140)
               } label: {
                  Text("App Theme")
                  Text("Light • Dark • System")
                     .font(.footnote)
               }
            }
            
            Section("About") {
               LabeledContent("Version", value: appVersion)
               LabeledContent("Cache Size", value: totalCacheSize)
               Button {
                  openFeedbackEmail()
               } label: {
                  HStack {
                     Text("Feedback")
                     Spacer()
                     Image(systemName: "arrow.up.right")
                        .foregroundStyle(.secondary)
                  }
               }
               .buttonStyle(.plain)
               Button {
                  isShowingPrivacyPolicy = true
               } label: {
                  Text("Privacy Policy")
                     .font(.headline)
                     .frame(maxWidth: .infinity)
                     .frame(height: 35)
                     .clipShape(Capsule())
               }
               .buttonStyle(.glassProminent)
            }
         }
         .navigationTitle("Settings")
         .preferredColorScheme(selectedTheme.colorScheme)
         .task {
            migrateLegacyThemeIfNeeded()
         }
         .sheet(isPresented: $isShowingPrivacyPolicy) {
            PrivacyPolicyView()
         }
         .alert("Mail App Unavailable", isPresented: $isShowingFeedbackFallbackAlert) {
            Button("Copy Email") {
               UIPasteboard.general.string = feedbackEmailAddress
            }
            Button("OK", role: .cancel) { }
         } message: {
            Text("Could not open Mail. Email us at \(feedbackEmailAddress).")
         }
      }
   }
   
   private var selectedTheme: AppTheme {
      AppTheme(rawValue: appThemeRawValue) ?? .system
   }
   
   private var selectedThemeBinding: Binding<AppTheme> {
      Binding(
         get: { selectedTheme },
         set: { appThemeRawValue = $0.rawValue }
      )
   }
   
   private func migrateLegacyThemeIfNeeded() {
      let defaults = UserDefaults.standard
      guard defaults.object(forKey: "appTheme") == nil else { return }
      guard defaults.object(forKey: "prefersDarkMode") != nil else { return }
      appThemeRawValue = prefersDarkMode ? AppTheme.dark.rawValue : AppTheme.light.rawValue
   }
   
   private var feedbackEmailURL: URL? {
      var components = URLComponents()
      components.scheme = "mailto"
      components.path = feedbackEmailAddress
      components.queryItems = [
         URLQueryItem(name: "subject", value: feedbackEmailSubject)
      ]
      return components.url
   }
   
   private func openFeedbackEmail() {
      guard let feedbackEmailURL else {
         isShowingFeedbackFallbackAlert = true
         return
      }
      
      openURL(feedbackEmailURL) { accepted in
         guard !accepted else { return }
         isShowingFeedbackFallbackAlert = true
      }
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



