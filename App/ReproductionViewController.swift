import ComposableArchitecture
import IssueReporting
import SwiftUI
import UIKit

final class ReproductionViewController: UIViewController {
	private let result = UILabel()
	private var probe: AppearanceProbe? = nil

	override func viewDidLoad() {
		super.viewDidLoad()
		view.backgroundColor = .systemBackground
		let probe = AppearanceProbe { [weak self] in
			DispatchQueue.main.async { self?.renderResult() }
		}
		self.probe = probe
		IssueReporters.current = [.default, probe]
		let repository = GuideRepository()
		let store = Store(initialState: Library.State()) { Library(repository: repository, probe: probe) }
		let hosting = UIHostingController(rootView: LibraryView(store: store, probe: probe))
		addChild(hosting)
		hosting.view.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(hosting.view)
		hosting.didMove(toParent: self)
		result.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
		result.numberOfLines = 0
		result.translatesAutoresizingMaskIntoConstraints = false
		view.addSubview(result)
		NSLayoutConstraint.activate([
			hosting.view.topAnchor.constraint(equalTo: view.topAnchor),
			hosting.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
			hosting.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
			hosting.view.bottomAnchor.constraint(equalTo: result.topAnchor),
			result.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
			result.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
			result.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
			result.heightAnchor.constraint(equalToConstant: 100),
		])
		renderResult()
	}

	private func renderResult() {
		guard let snapshot = probe?.snapshot else { return }
		result.text = """
		Callbacks inside trigger: \(snapshot.appearancesDuringTrigger)
		Diagnostics: \(snapshot.diagnostics.count)
		Trigger + SwiftUI stack: \(snapshot.hasTriggerAppearanceStack ? "captured" : "none")
		"""
		print("[Reproduction] \(result.text ?? "")")
	}
}
