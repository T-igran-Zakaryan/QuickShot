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
      var body: some Scene {
         WindowGroup {
            TabView(selection: $selectedTab) {
               Tab("Images", systemImage: "photo.stack", value: 1) {
                  AssetGridView()
               }
               Tab("PDFs", systemImage: "folder", value: 2) {
                  PDFListView()
               }
               Tab("Settings", systemImage: "gearshape", value: 3) {
                  SettingsView()
               }
            }
         }
    }
}
