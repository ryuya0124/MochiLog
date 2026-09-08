# Import regression checks

`bash scripts/test-shared-import.sh` compiles the production queue, text reader and date parser on macOS, with a minimal settings/UI-model stub. It checks cold-launch buffering, exclusive consumption, arrival during processing, duplicate delivery, retries, presentation preferences, UTF-8/UTF-16/Shift-JIS decoding, missing inputs and old/new timestamp formats.

`Fixtures/` contains synthetic analytics data, not exported user logs. The valid fixture has a timestamp without fractional seconds, exercising the regression where these timestamps were previously rejected.

Build the app and embedded Watch app using a destination, without overriding the SDK for every target:

```sh
xcodebuild -project MochiLog.xcodeproj -scheme MochiLog -configuration Debug \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

On an isolated simulator with iCloud disabled, import the valid fixture with three different dates, a fourth copy with the first date, and the invalid fixture. Expect 3 saved, 1 duplicate, and 1 error. Repeat on a compact phone, iPad mini, a large iPad and with accessibility text sizes. Relaunch and verify the saved records persist. Test both a terminated app and an already running app.

The containing app uses `UISceneDelegate` for both `connectionOptions.urlContexts` and `scene(_:openURLContexts:)`. No share extension is involved. Simulator `openurl` exercises delivery to the main app; a physical-device check from Files and Settings Analytics is still needed to verify each source app's multi-selection behavior.
