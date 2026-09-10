fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios sync_certificates

```sh
[bundle exec] fastlane ios sync_certificates
```

match証明書を同期（読み取り専用）

### ios build_appstore

```sh
[bundle exec] fastlane ios build_appstore
```

App Store提出用の署名付きIPAをビルド

### ios upload_testflight

```sh
[bundle exec] fastlane ios upload_testflight
```

TestFlightにアップロード

### ios release

```sh
[bundle exec] fastlane ios release
```

App Store用にビルドしてTestFlightにアップロード

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
