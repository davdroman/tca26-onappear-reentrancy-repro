import ComposableArchitecture
import IssueReporting
import SwiftUI
import UIKit

final class ReproductionViewController: UIViewController {
	private let result = UILabel()
	private let listContainer = UIView()
	private var hosting: UIHostingController<AppearanceListView>? = nil
	private var probe: AppearanceProbe? = nil
	private var store: StoreOf<AppearanceList>? = nil
	private var deferred = false

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground
		let title = UILabel()
		title.text = "TCA26 · onAppear"
		title.font = .preferredFont(forTextStyle: .title1)
		let explanation = UILabel()
		explanation.text = "Each run lays out a fresh lazy list, then deletes and clears it while initial appearances are pending."
		explanation.font = .preferredFont(forTextStyle: .body)
		explanation.numberOfLines = 0
		let synchronous = UIButton(type: .system, primaryAction: UIAction(title: "Run synchronous") { [weak self] _ in
			self?.run(deferred: false)
		})
		synchronous.configuration = .filled()
		let control = UIButton(type: .system, primaryAction: UIAction(title: "Run deferred control") { [weak self] _ in
			self?.run(deferred: true)
		})
		control.configuration = .tinted()
		result.text = "Choose a mode to begin."
		result.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
		result.numberOfLines = 0
		result.accessibilityIdentifier = "result"
		let controls = UIStackView(arrangedSubviews: [title, explanation, synchronous, control, result])
		controls.axis = .vertical
		controls.spacing = 16
		controls.translatesAutoresizingMaskIntoConstraints = false
		listContainer.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(controls)
		view.addSubview(listContainer)
		NSLayoutConstraint.activate([
			controls.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 20),
			controls.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
			controls.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
			listContainer.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 16),
			listContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			listContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			listContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
		])
	}

	private func run(deferred: Bool) {
		hosting?.willMove(toParent: nil)
		hosting?.view.removeFromSuperview()
		hosting?.removeFromParent()
		self.deferred = deferred
		result.text = "Running \(deferred ? "deferred control" : "synchronous")…"
		view.layoutIfNeeded()
		let probe = AppearanceProbe { [weak self] in
			DispatchQueue.main.async { self?.renderResult() }
		}
		self.probe = probe
		IssueReporters.current = [.default, probe]
		let store = Store(initialState: AppearanceList.State()) { AppearanceList(probe: probe) }
		self.store = store
		let hosting = UIHostingController(rootView: AppearanceListView(
			store: store, deferAppearanceActions: deferred, probe: probe,
		))
		self.hosting = hosting
		addChild(hosting)
		hosting.view.frame = listContainer.bounds
		hosting.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		listContainer.addSubview(hosting.view)
		hosting.didMove(toParent: self)
		view.window?.layoutIfNeeded()
		let task = store.send(.deleteButtonTapped)
		Task { @MainActor [weak self] in
			await task?.value
			self?.renderResult()
		}
	}

	private func renderResult() {
		guard let probe, let store else { return }
		let snapshot = probe.snapshot
		let matched = snapshot.diagnostics.contains { $0.contains("Can't send another action before handling this one") }
		let succeeded = store.rows.isEmpty && snapshot.appearancesDuringTrigger > 0 && (
			deferred
				? snapshot.diagnostics.isEmpty && snapshot.deferredActionsAfterTrigger == snapshot.appearancesDuringTrigger
				: matched && snapshot.hasTriggerAppearanceStack
		)
		result.text = """
		Mode: \(deferred ? "Deferred control" : "Synchronous")
		\(succeeded ? (deferred ? "CONTROL PASSED" : "REPRODUCED") : "Not reproduced")
		Callbacks inside trigger: \(snapshot.appearancesDuringTrigger)
		Deferred actions afterward: \(snapshot.deferredActionsAfterTrigger)
		Diagnostics: \(snapshot.diagnostics.count)
		Trigger + SwiftUI stack: \(snapshot.hasTriggerAppearanceStack ? "captured" : "none")
		Rows remaining: \(store.rows.count)
		"""
		print("[Reproduction] \(result.text ?? "")")
	}
}
