import ComposableArchitecture
import SwiftUI

@Feature struct AppearanceList {
	struct State {
		var rows = Array(0..<30)
		var appearances = 0
		@Trigger var refresh
	}

	enum Action {
		case deleteButtonTapped
		case rowAppeared(Int, wasDeferredFromTrigger: Bool)
	}

	let probe: AppearanceProbe

	var body: some Feature {
		Update { state, action in
			switch action {
			case .deleteButtonTapped:
				store.addTask {
					try withAnimation {
						_ = try store.modify {
							if !$0.rows.isEmpty { $0.rows.removeFirst() }
						}
					}
					try store.refresh()
				}
			case let .rowAppeared(_, wasDeferredFromTrigger):
				state.appearances += 1
				if wasDeferredFromTrigger { probe.recordDeferredAction() }
			}
		}
		.onTrigger(store.refresh) { state in
			probe.isInsideTrigger = true
			defer { probe.isInsideTrigger = false }
			state.rows = []
		}
	}
}

struct AppearanceListView: View {
	let store: StoreOf<AppearanceList>
	let deferAppearanceActions: Bool
	let probe: AppearanceProbe

	var body: some View {
		ScrollView {
			LazyVStack {
				ForEach(store.rows, id: \.self) { row in
					Text("Row \(row)")
						.frame(height: 140)
						.frame(maxWidth: .infinity)
						.onAppear {
							let appearedDuringTrigger = probe.recordAppearance()
							if deferAppearanceActions {
								Task { @MainActor in
									store.send(.rowAppeared(row, wasDeferredFromTrigger: appearedDuringTrigger))
								}
							} else {
								store.send(.rowAppeared(row, wasDeferredFromTrigger: false))
							}
						}
				}
			}
		}
	}
}
