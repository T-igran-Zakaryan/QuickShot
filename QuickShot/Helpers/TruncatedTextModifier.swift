//
//  TruncatedTextModifier.swift
//  Better Player
//
//  Created by Тигран Закарян on 13.07.25.
//

import SwiftUI

struct TruncatedTextModifier: ViewModifier {
    let text: String
    let charLimit = 7

    var truncatedText: String {
        text.truncatedMiddle(charLimit: charLimit)
    }

    func body(content: Content) -> some View {
        Text(truncatedText)
    }
}

extension View {
    func truncatedText(_ text: String) -> some View {
        modifier(TruncatedTextModifier(text: text))
    }

    func truncatedNavigationTitle(_ text: String) -> some View {
        navigationTitle(text.truncatedMiddle(charLimit: 7))
    }
}

extension String {
    func truncatedMiddle(charLimit: Int) -> String {
        guard count > charLimit * 2 else {
            return self
        }
        let firstPart = prefix(charLimit)
        let secondPart = suffix(charLimit)
        return "\(firstPart)...\(secondPart)"
    }
}
