// HomeView+LogProcessing.swift
// ログ処理関連のメソッドをHomeViewから分離
import SwiftData
import SwiftUI

// MARK: - 共通処理メソッド
extension HomeView {
  /// デバイス名とモデルコードを解決する
  private func resolveDeviceName(from result: LogParser.ParseResult) -> (
    deviceName: String, modelCode: String?
  ) {
    var deviceName = "Unknown"
    var deviceModelCodeToUse: String? = result.detectedIdentifier ?? result.deviceModelCode

    if let id = deviceModelCodeToUse,
      let resolved = DeviceLibrary.getDeviceName(for: id)
    {
      deviceName = resolved
    }

    if deviceName == "Unknown" {
      if let localId = DeviceLibrary.localModelIdentifier(),
        let resolved = DeviceLibrary.getDeviceName(for: localId)
      {
        deviceName = resolved
        deviceModelCodeToUse = localId
      }
    }

    return (deviceName, deviceModelCodeToUse)
  }

  /// レコードを保存する（キャッシュ追加 + データベース挿入）
  private func saveRecord(_ record: BatteryRecord, deviceName: String) {
    // キャッシュに追加（save前に行う）
    let key = "\(record.logDate.timeIntervalSince1970)_\(deviceName)"
    HomeView.recentlyAddedLogs[key] = Date()

    // UIアニメーションとデータ挿入
    withAnimation(.snappy) {
      modelContext.insert(record)
    }

    // 保存はアニメーション外で行う
    Task.detached(priority: .userInitiated) {
      await MainActor.run {
        try? self.modelContext.save()
      }
    }
  }

  /// WatchOSデバイスかどうかを判定する
  private func isWatchDevice(parseResult: LogParser.ParseResult, deviceName: String) -> Bool {
    let isWatchOS = parseResult.osVersion?.lowercased().contains("watch") ?? false
    let looksLikeWatch = deviceName.contains("Apple Watch")
    return isWatchOS || looksLikeWatch
  }

  /// Watch処理を行う
  /// - Returns: (作成されたレコード, 処理を終了すべきか)
  private func handleWatchRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    modelCode: String?,
    logDate: Date,
    silent: Bool
  ) -> (record: BatteryRecord?, shouldReturn: Bool) {
    // 登録済みWatchモデルがある場合
    if let registeredWatch = AppSettings.shared.registeredWatchModel {
      // 重複チェック（設定に応じて）
      if !AppSettings.shared.allowDuplicateRecords,
        hasDuplicateRecord(on: logDate, deviceName: registeredWatch)
      {
        if silent {
          NotificationHelper.scheduleImportResultNotification(
            title: String(localized: "import_silent_failure"),
            body: String(localized: "duplicate_record")
          )
          return (nil, true)
        } else {
          // すべてのHomeViewインスタンスにエラーを通知
          DispatchQueue.main.async {
            NotificationCenter.default.post(
              name: NSNotification.Name("ShowImportError"),
              object: nil,
              userInfo: ["errorMessage": String(localized: "duplicate_record")]
            )
          }
          return (nil, true)
        }
      }

      // レコード作成
      let registeredModelCode =
        DeviceLibrary.getIdentifierForDeviceName(registeredWatch) ?? modelCode
      let registeredDesignCap = DeviceLibrary.getCapacity(for: registeredWatch)
      let newRecord = createRecord(
        from: result,
        deviceName: registeredWatch,
        deviceModelCodeOverride: registeredModelCode,
        designCapacityOverride: registeredDesignCap
      )

      // レコード保存
      saveRecord(newRecord, deviceName: registeredWatch)

      // サイレントモードの場合は通知
      if silent {
        let body = String(
          format: String(localized: "import_silent_success_body"),
          registeredWatch,
          DateFormatter.localizedString(
            from: newRecord.logDate, dateStyle: .medium, timeStyle: .short)
        )
        NotificationHelper.scheduleImportResultNotification(
          title: String(localized: "import_silent_success"),
          body: body
        )
      }

      return (newRecord, silent)
    }

    // 登録済みWatchモデルがない場合
    if silent {
      // サイレントモードではエラー通知
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_failure"),
        body: String(localized: "watch_selection_required")
      )
      return (nil, true)
    } else {
      // 対話モードではWatch選択画面を表示
      pendingParseResult = result
      showingWatchSelection = true
      return (nil, true)
    }
  }

  /// 通常デバイス（iPhone/iPad）の処理を行う
  private func handleNormalDeviceRecord(
    from result: LogParser.ParseResult,
    deviceName: String,
    modelCode: String?,
    logDate: Date,
    silent: Bool
  ) -> BatteryRecord? {
    // 重複チェック（設定に応じて）
    if !AppSettings.shared.allowDuplicateRecords,
      hasDuplicateRecord(on: logDate, deviceName: deviceName)
    {
      if silent {
        NotificationHelper.scheduleImportResultNotification(
          title: String(localized: "import_silent_failure"),
          body: String(localized: "duplicate_record")
        )
        return nil
      } else {
        // すべてのHomeViewインスタンスにエラーを通知
        DispatchQueue.main.async {
          NotificationCenter.default.post(
            name: NSNotification.Name("ShowImportError"),
            object: nil,
            userInfo: ["errorMessage": String(localized: "duplicate_record")]
          )
        }
        return nil
      }
    }

    // レコード作成
    let designCap = DeviceLibrary.getCapacity(for: deviceName)
    let newRecord = createRecord(
      from: result,
      deviceName: deviceName,
      deviceModelCodeOverride: modelCode,
      designCapacityOverride: designCap
    )

    // レコード保存
    saveRecord(newRecord, deviceName: deviceName)

    // サイレントモードの場合は通知
    if silent {
      let body = String(
        format: String(localized: "import_silent_success_body"),
        deviceName,
        DateFormatter.localizedString(
          from: newRecord.logDate, dateStyle: .medium, timeStyle: .short)
      )
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_success"),
        body: body
      )
    }

    return newRecord
  }
}

// MARK: - ログ処理
extension HomeView {
  /// ログテキストを非同期で解析・処理する
  func processLogTextAsync(_ text: String, silent: Bool = false, contentHash: Int? = nil) {
    isProcessing = true

    let enableValidation = AppSettings.shared.enableCapacityValidation
    let threshold = AppSettings.shared.capacityValidationThreshold

    DispatchQueue.global(qos: .userInitiated).async {
      let parseResult = LogParser.parse(
        text: text,
        enableValidation: enableValidation,
        validationThreshold: threshold
      )

      DispatchQueue.main.async {
        isProcessing = false

        // 処理完了を通知（MochiLogAppのフラグをリセットするため）
        if let hash = contentHash {
          NotificationCenter.default.post(
            name: NSNotification.Name("SharedLogProcessingCompleted"),
            object: nil,
            userInfo: ["contentHash": hash]
          )

          // HomeViewのprocessingContentHashesからも削除
          HomeView.processingLock.lock()
          HomeView.processingContentHashes.remove(hash)
          HomeView.processingLock.unlock()
        }

        // UI更新（アラート表示や画面遷移）のために少し遅延させる
        // iPadではOverlayが消えるのと遷移が競合すると詳細画面が開かないことがあるため
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
          if !silent {
            // Normal interactive flow: existing behavior
            if let newRecord = self.addRecordFromParseResult(parseResult) {
              // 0.5秒遅延してから通知を送信（SwiftDataの更新を待つ）
              DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                NotificationCenter.default.post(
                  name: NSNotification.Name("ShowRecordDetail"),
                  object: nil,
                  userInfo: [
                    "logDate": newRecord.logDate,
                    "deviceName": newRecord.deviceName,
                  ]
                )
              }
            }
            return
          }

          // Silent mode flow
          self.handleSilentImport(parseResult)
        }
      }
    }
  }

  /// サイレントインポート処理（共有シートからのバックグラウンド処理）
  func handleSilentImport(_ parseResult: LogParser.ParseResult) {
    // 基本的なバリデーション
    let canCreate =
      (parseResult.logDate != nil) && (parseResult.cycleCount != nil)
      && (parseResult.nominalCapacity != nil) && (parseResult.rawCapacity != nil)

    if !canCreate {
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_failure"),
        body: String(localized: "parse_error")
      )
      redirectToSettingsAfterSilentImport()
      return
    }

    // 容量不一致チェック
    if parseResult.isCapacityMismatch && AppSettings.shared.mismatchBehavior == .error {
      NotificationHelper.scheduleImportResultNotification(
        title: String(localized: "import_silent_failure"),
        body: String(localized: "capacity_mismatch_error")
      )
      redirectToSettingsAfterSilentImport()
      return
    }

    // デバイス名解決
    let (deviceName, modelCode) = resolveDeviceName(from: parseResult)
    guard let logDate = parseResult.logDate else { return }

    // Watch判定と処理
    if isWatchDevice(parseResult: parseResult, deviceName: deviceName) {
      let (_, shouldReturn) = handleWatchRecord(
        from: parseResult,
        deviceName: deviceName,
        modelCode: modelCode,
        logDate: logDate,
        silent: true
      )
      if shouldReturn {
        redirectToSettingsAfterSilentImport()
      }
      return
    }

    // 通常デバイス処理
    _ = handleNormalDeviceRecord(
      from: parseResult,
      deviceName: deviceName,
      modelCode: modelCode,
      logDate: logDate,
      silent: true
    )
    redirectToSettingsAfterSilentImport()
  }

  /// 解析結果からレコードを追加する（対話的なフロー用）
  func addRecordFromParseResult(_ result: LogParser.ParseResult) -> BatteryRecord? {
    // バリデーション
    guard let logDate = result.logDate,
      result.cycleCount != nil,
      result.nominalCapacity != nil,
      result.rawCapacity != nil
    else {
      DispatchQueue.main.async {
        NotificationCenter.default.post(
          name: NSNotification.Name("ShowImportError"),
          object: nil,
          userInfo: ["errorMessage": String(localized: "parse_error")]
        )
      }
      return nil
    }

    // 容量不一致チェック
    if result.isCapacityMismatch {
      if appSettings.mismatchBehavior == .error {
        DispatchQueue.main.async {
          NotificationCenter.default.post(
            name: NSNotification.Name("ShowImportError"),
            object: nil,
            userInfo: ["errorMessage": String(localized: "capacity_mismatch_error")]
          )
        }
        return nil
      } else {
        pendingParseResult = result
        showingMismatchAlert = true
        return nil
      }
    }

    // デバイス名解決
    let (deviceName, modelCode) = resolveDeviceName(from: result)

    // Watch判定と処理
    if isWatchDevice(parseResult: result, deviceName: deviceName) {
      let (record, _) = handleWatchRecord(
        from: result,
        deviceName: deviceName,
        modelCode: modelCode,
        logDate: logDate,
        silent: false
      )
      return record
    }

    // 通常デバイス処理
    return handleNormalDeviceRecord(
      from: result,
      deviceName: deviceName,
      modelCode: modelCode,
      logDate: logDate,
      silent: false
    )
  }
}
