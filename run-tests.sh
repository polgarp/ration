#!/bin/bash
# Builds and runs the Swift unit tests, then the shell tests for the tap.
# Needs only Command Line Tools — no Xcode.
#
# Tests/test-installer.sh is not run here: it drives the built app bundle, so
# it needs ./build.sh first and is run on its own.
cd "$(dirname "$0")" || exit 1
set -e
OUT=.build
mkdir -p "$OUT"
swiftc -O -o "$OUT/tests" Sources/Core/*.swift Tests/Harness.swift Tests/MetricsTests.swift Tests/SnapshotTests.swift Tests/SnapshotStoreTests.swift Tests/ServiceStatusTests.swift Tests/InstallerTests.swift Tests/FormatTests.swift Tests/FileFreshnessTests.swift Tests/MenuModelTests.swift Tests/main.swift
"$OUT/tests"
echo
./Tests/test-tap.sh
