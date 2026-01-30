//
//  MochiLogApp.swift
//  MochiLog Watch App
//
//  Created by りゅうや on 2026/01/30.
//

import SwiftUI

@main
struct MochiLog_Watch_AppApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView()
        .environmentObject(WatchConnectivityManager.shared)
        .onAppear {
          // Watch Connectivityセッションを開始
          WatchConnectivityManager.shared.startSession()
        }
    }
  }
}
