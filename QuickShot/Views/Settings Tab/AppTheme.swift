//
//  AppTheme.swift
//  QuickShot
//
//  Created by Тигран Закарян on 25.04.26.
//
import SwiftUI

enum AppTheme: String, CaseIterable, Identifiable {
   case light
   case dark
   case system
   
   var id: String { rawValue }
   
   var iconName: String {
      switch self {
      case .light:
         "sun.max.fill"
      case .dark:
         "moon.fill"
      case .system:
         "circle.lefthalf.filled"
      }
   }
   
   var colorScheme: ColorScheme? {
      switch self {
      case .light:
            .light
      case .dark:
            .dark
      case .system:
         nil
      }
   }
}
