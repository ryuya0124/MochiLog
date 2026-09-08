#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-cloud-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 MochiLog/Services/CloudKitErrorInspector.swift Tests/CloudKitErrorTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
