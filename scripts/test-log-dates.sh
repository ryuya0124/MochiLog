#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-date-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -O -parse-as-library -swift-version 5 MochiLog/Services/LogDateParser.swift Tests/LogDatePerformanceTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
