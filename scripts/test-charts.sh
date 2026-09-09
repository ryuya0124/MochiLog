#!/bin/bash
set -eu
cd "$(dirname "$0")/.."
TEST_BINARY=$(mktemp -t mochilog-chart-tests)
trap 'rm -f "$TEST_BINARY"' EXIT
xcrun swiftc -parse-as-library -swift-version 5 \
  MochiLog/Utilities/ChartWindowNavigator.swift \
  MochiLog/Utilities/ChartAxisHelper.swift Tests/ChartLogicTests.swift -o "$TEST_BINARY"
TZ=Asia/Tokyo "$TEST_BINARY"
TZ=America/Los_Angeles "$TEST_BINARY"
