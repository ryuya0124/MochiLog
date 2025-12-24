# Changelog

## 2025-12-25

- Views を機能別サブフォルダに整理しました。
  - Home: `ContentView.swift`, `HomeView.swift`
  - Settings: `SettingsView.swift`, `DonationView.swift`
  - Support: `SupportFormView.swift`
  - Records: `RecordViews.swift`
  - Components: `HierarchicalDevicePickerView.swift`
  - Legal: `PrivacyPolicyView.swift`, `TermsOfUseView.swift`
  - Onboarding: `TutorialView.swift`
  - Analytics: `AnalyticsView.swift`

- ファイルは `git mv` で移動し、Xcode でビルド確認（Debug / iOS Simulator）済みです。