//
//  BundleExtension.swift
//  QuickShot
//
//  Created by Тигран Закарян on 20.03.26.
//
import SwiftUI

extension Bundle {
    var appVersionDisplayString: String {
        let version = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String

        switch (version, build) {
        case let (version?, build?) where version != build:
            return "\(version) (\(build))"
        case let (version?, _):
            return version
        case let (_, build?):
            return build
        default:
            return "Unavailable"
        }
    }
}
