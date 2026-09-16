//
//  TurboKillerApp.swift
//  TurboKiller
//
//  Created by NicoTech Studio on 2026/9/16.
//

import AppKit
import SwiftUI

@main
struct TurboKillerApp: App {
    var body: some Scene {
        MenuBarExtra("TurboKiller", systemImage: "wind") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
