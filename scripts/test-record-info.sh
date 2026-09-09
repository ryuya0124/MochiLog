#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-record-info-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library MochiLog/Services/RecordInfoPreferences.swift Tests/RecordInfoPreferencesTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
