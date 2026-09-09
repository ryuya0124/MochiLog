#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-batch-parser-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 Shared/SharedLogInbox.swift MochiLog/Services/SharedImportQueue.swift MochiLog/Services/LogParser.swift MochiLog/Services/LogDateParser.swift Tests/BatchLogParserTests.swift -o "$TEST_BINARY"
"$TEST_BINARY" "$@"
