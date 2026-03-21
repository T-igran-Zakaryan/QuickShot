//
//  ToolBarGroup.swift
//  QuickShot
//
//  Created by Тигран Закарян on 21.03.26.
//

import SwiftUI

struct ToolBarGroup: ToolbarContent {
   let onAdd: () -> Void
   
   
   var body: some ToolbarContent {
//      ToolbarItem(placement: .topBarTrailing) {
//         Button("Cancel", systemImage: "xmark") {}
//      }
      
//      ToolbarItemGroup(placement: .primaryAction) {
//         Button("Erase", systemImage: "eraser") {}
//      }
//      
//      ToolbarSpacer(.fixed)
      // this should be used for separating the items
//      ToolbarItem(placement: .confirmationAction) {
//         Button("Scan", systemImage: "document.viewfinder", action: onAdd)
//      }
      ToolbarItem(placement: .topBarTrailing) {
         Button("Scan", systemImage: "document.viewfinder", action: onAdd)
      }
   }
}
