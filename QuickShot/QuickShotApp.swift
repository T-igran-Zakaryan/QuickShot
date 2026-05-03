//
//  QuickShotApp.swift
//  QuickShot
//
//  Created by Тигран Закарян on 08.03.26.
//

import SwiftUI

@main
struct QuickShotApp: App {
    @State private var selectedTab = 1
    @AppStorage("showsDocumentsTab") private var showsDocumentsTab = false
    @AppStorage("appTheme") private var appThemeRawValue = AppTheme.system.rawValue

    var body: some Scene {
        WindowGroup {
            TabView(selection: $selectedTab) {
                Tab("Images", systemImage: "photo.stack", value: 1) {
                    ImagesGridView()
                }

                if showsDocumentsTab {
                    Tab("Documents", systemImage: "doc.text.image", value: 4) {
                        DocumentsView()
                    }
                }

                Tab("PDFs", systemImage: "folder", value: 2) {
                    PDFListView()
                }

                Tab("Settings", systemImage: "gear", value: 3) {
                    SettingsView()
                }
            }
            .preferredColorScheme(selectedTheme.colorScheme)
            .animation(.easeInOut(duration: 0.25), value: selectedTheme)
        }
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: appThemeRawValue) ?? .system
    }
}
