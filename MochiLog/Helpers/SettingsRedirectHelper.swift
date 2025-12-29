// SettingsRedirectHelper.swift
// 設定アプリへのリダイレクト処理を提供するヘルパー

import UIKit

/// 設定アプリへのリダイレクト処理を提供する
enum SettingsRedirectHelper {
  /// silentインポート完了後に設定アプリ（解析・改善データ画面）にリダイレクトする
  /// 「アプリを開く」がオフの場合、ユーザーはアプリを見たくないので即座に元の画面に戻す
  static func redirectToPrivacyAnalytics() {
    // iOS 18以降ではprefs: URLスキームが制限されているため、複数のURLパターンを試す
    let urlStrings = [
      "App-prefs:Privacy&path=PROBLEM_REPORTING",
      "App-prefs:Privacy",
      "App-prefs:",
    ]

    openFirstValidURL(urlStrings)
  }

  /// URLリストから最初に成功するものを開く
  private static func openFirstValidURL(_ urlStrings: [String], index: Int = 0) {
    guard index < urlStrings.count else { return }

    if let url = URL(string: urlStrings[index]) {
      UIApplication.shared.open(url) { success in
        if !success {
          openFirstValidURL(urlStrings, index: index + 1)
        }
      }
    } else {
      openFirstValidURL(urlStrings, index: index + 1)
    }
  }
}
