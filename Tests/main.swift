import Foundation

let t = Harness()
runMetricsTests(t)
runSnapshotTests(t)
runFormatTests(t)
runMenuModelTests(t)
t.finish()
