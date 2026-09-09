#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-import-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 \
  Shared/SharedLogInbox.swift MochiLog/Services/SharedImportQueue.swift MochiLog/Services/LogDateParser.swift Tests/SharedImportQueueTests.swift \
  -o "$TEST_BINARY"
"$TEST_BINARY"
