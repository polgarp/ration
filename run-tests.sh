#!/bin/bash
# Builds and runs the Swift unit tests, then the shell tests for the tap.
# Needs only Command Line Tools — no Xcode.
cd "$(dirname "$0")" || exit 1
set -e
OUT=.build
mkdir -p "$OUT"
swiftc -O -o "$OUT/tests" Sources/Core/*.swift Tests/Harness.swift Tests/MetricsTests.swift Tests/SnapshotTests.swift Tests/FormatTests.swift Tests/MenuModelTests.swift Tests/main.swift
"$OUT/tests"
