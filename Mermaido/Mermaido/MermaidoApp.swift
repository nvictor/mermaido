//
//  MermaidoApp.swift
//  Mermaido
//
//  Created by Victor Noagbodji on 11/17/25.
//

import SwiftUI

@main
struct MermaidoApp: App {
    @StateObject private var updater = AppUpdater()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CheckForUpdatesCommands(updater: updater)
        }
    }
}
