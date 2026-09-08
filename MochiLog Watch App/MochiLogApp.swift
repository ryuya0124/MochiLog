//
//  MochiLogApp.swift
//  MochiLog Watch App
//
//  Created by りゅうや on 2026/01/30.
//

import SwiftUI

@main
struct MochiLog_Watch_AppApp: App {
  @StateObject private var languageSettings = LanguageSettings.shared
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(\.locale, L10n.locale)
        .id(languageSettings.selection)
        .environmentObject(WatchConnectivityManager.shared)
        .onAppear {
          // Watch Connectivityセッションを開始
          WatchConnectivityManager.shared.startSession()
        }
    }
  }
}
