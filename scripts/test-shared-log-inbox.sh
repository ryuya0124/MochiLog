#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-shared-inbox-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library Shared/SharedLogInbox.swift Tests/SharedLogInboxTests.swift -o "$TEST_BINARY"
"$TEST_BINARY"
