import Foundation

let t = Harness()
runMetricsTests(t)
runSnapshotTests(t)
runSnapshotStoreTests(t)
runServiceStatusTests(t)
runInstallerTests(t)
runFormatTests(t)
runFileFreshnessTests(t)
runMenuModelTests(t)
t.finish()
