//
//  PrivacyPolicyView.swift
//  QuickShot
//
//  Created by Тигран Закарян on 25.04.26.
//
import SwiftUI

struct PrivacyPolicyView: View {
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
