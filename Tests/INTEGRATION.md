# Integration checks

Run the deterministic checks from the repository root on macOS with Xcode selected:

```sh
bash scripts/test-shared-import.sh
bash scripts/test-languages.sh
bash scripts/test-watch-records.sh
bash scripts/test-cloud-errors.sh
```

`MochiLogUITests` exercises the language picker, device-language selection, persistence after relaunch, and layout at the largest accessibility text size. It runs with iCloud disabled and does not use personal records.

The Watch checks cover backward-compatible payload decoding and diagnostic identifiers independent of the sending phone's language. Simulator synchronization checks use the synthetic iPhone fixture in `Tests/Fixtures`.

`MochiLogWatchUITests` opens synchronized records and scrolls through the real detail views in German on watchOS 27. Import a fixture on the paired phone first. The test uses German as the Watch's device language and the default app language setting. It saves screen images both as XCTest attachments and in the test runner's temporary directory.

When running UI tests, `-collect-test-diagnostics never` avoids lengthy simulator diagnostic collection after an assertion failure; normal test logs and screenshot attachments are still retained.

Watch UI tests wait for the launch transition, tap the visible device name, and check that scrolled labels are inside the screen with room for their values. The first injected tap was intermittent on the watchOS 27 simulator, particularly at 40 mm, including taps on both the row center and its text. The test records an attachment and retries once only if the destination is absent and the source is still visible. This is a documented automation limitation, not proof that navigation always responds to the first tap; the cause and physical-device behavior still need verification.

The localization audit checks every string catalog in the phone app, Watch app and shared resources for all eight supported languages, empty translations and compatible argument placeholders. It does not judge translation quality or translate raw operating-system diagnostic logs.

The iCloud diagnostic command checks local numeric/date values and account availability. It does not create test records in Core Data's CloudKit zone and does not claim that an upload succeeded. End-to-end iCloud synchronization must additionally be checked with signed apps and a test iCloud account on two devices.

For release review, also share multiple files from Files into the app on physical hardware. Simulator `openurl` and queue tests cannot reproduce every file provider's security-scoped URL behavior.
