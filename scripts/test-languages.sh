#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-language-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 Shared/Localization.swift Tests/LanguageTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
python3 scripts/audit-localizations.py
