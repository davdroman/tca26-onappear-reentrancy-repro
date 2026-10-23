import IssueReporting
import Synchronization

final class AppearanceProbe: IssueReporter {
	struct Snapshot {
		var isInsideTrigger = false
		var appearancesDuringTrigger = 0
		var diagnosticCount = 0
	}

	private let values = Mutex(Snapshot())
	let onUpdate: @Sendable () -> Void

	init(onUpdate: @escaping @Sendable () -> Void) {
		self.onUpdate = onUpdate
	}

	var snapshot: Snapshot { values.withLock { $0 } }

	func reset() {
		values.withLock { $0 = Snapshot() }
		onUpdate()
	}

	var isInsideTrigger: Bool {
		get { values.withLock { $0.isInsideTrigger } }
		set { values.withLock { $0.isInsideTrigger = newValue } }
	}

	func recordAppearance() {
		values.withLock {
			if $0.isInsideTrigger { $0.appearancesDuringTrigger += 1 }
		}
	}

	func reportIssue(
		_ message: @autoclosure () -> String?,
		severity: IssueSeverity,
		fileID: StaticString,
		filePath: StaticString,
		line: UInt,
		column: UInt,
	) {
		values.withLock {
			$0.diagnosticCount += 1
		}
		onUpdate()
	}
}
