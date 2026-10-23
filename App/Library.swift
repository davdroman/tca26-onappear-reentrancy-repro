import ComposableArchitecture
import Foundation
import SwiftUI

struct Guide: Codable, Identifiable, Hashable, Sendable {
	let id: Int
	let city: String
	let topic: String

	var title: String { "\(city): \(topic)" }

	static let samples: [Guide] = [
		"Lisbon", "Kyoto", "Copenhagen", "Melbourne", "Porto",
		"Edinburgh", "Vancouver", "Oslo", "Valencia", "Taipei",
	]
	.enumerated()
	.flatMap { cityIndex, city in
		["Neighborhood walks", "Markets", "Gardens", "Architecture", "Bookshops", "Waterfronts"]
			.enumerated()
			.map { topicIndex, topic in
				Guide(id: cityIndex * 6 + topicIndex, city: city, topic: topic)
			}
	}
}

actor GuideRepository {
	private let url = URL.documentsDirectory.appending(path: "guides.json")

	struct Page: Sendable {
		let guides: [Guide]
		let totalCount: Int
	}

	func page(offset: Int) throws -> Page {
		if !FileManager.default.fileExists(atPath: url.path) { try restore() }
		let guides = try JSONDecoder().decode([Guide].self, from: Data(contentsOf: url))
		return Page(guides: Array(guides.dropFirst(offset).prefix(12)), totalCount: guides.count)
	}

	func remove(id: Int) throws {
		var guides = try JSONDecoder().decode([Guide].self, from: Data(contentsOf: url))
		guides.removeAll { $0.id == id }
		try JSONEncoder().encode(guides).write(to: url, options: .atomic)
	}

	func restore() throws {
		try JSONEncoder().encode(Guide.samples).write(to: url, options: .atomic)
	}
}

@Feature struct Library {
	struct State {
		var feed = Spawn<GuideFeed>(GuideFeed.State())
	}

	enum Action {
		case restoreSamplesTapped
	}

	let repository: GuideRepository
	let probe: AppearanceProbe

	var body: some Feature {
		Update { _, action in
			switch action {
			case .restoreSamplesTapped:
				store.addTask {
					try await repository.restore()
					try store.feed.reload()
				}
			}
		}
		.spawn(\.feed) { GuideFeed(repository: repository, probe: probe) }
		.onEvent(GuideFeed.Removed.self) { _, _ in
			store.addTask { try store.feed.reload() }
		}
	}
}

@Feature struct GuideFeed {
	struct State {
		var guides: [Guide]? = nil
		var hasMore = true
		var isLoading = false
		var totalCount = 0
		@Trigger var reload
	}

	enum Action {
		case guideAppeared(Int)
		case removeTapped(Int)
	}

	enum Removed: FeatureEventKey {
		typealias Value = Void
	}

	let repository: GuideRepository
	let probe: AppearanceProbe

	var body: some Feature {
		Update { state, action in
			switch action {
			case let .guideAppeared(id):
				guard
					state.hasMore, !state.isLoading,
					let guides = state.guides,
					let index = guides.firstIndex(where: { $0.id == id }),
					index >= guides.count - 6
				else { return }
				state.isLoading = true
				let offset = guides.count
				store.addTask {
					let next = try await repository.page(offset: offset)
					try store.modify {
						$0.guides?.append(contentsOf: next.guides)
						$0.totalCount = next.totalCount
						$0.hasMore = ($0.guides?.count ?? 0) < next.totalCount
						$0.isLoading = false
					}
				}
			case let .removeTapped(id):
				probe.reset()
				store.addTask {
					try await repository.remove(id: id)
					try withAnimation {
						_ = try store.modify { $0.guides?.removeAll { $0.id == id } }
					}
					try store.post(key: Removed.self, value: ())
				}
			}
		}
		.onMount { _ in
			store.addTask { try store.reload() }
		}
		.onTrigger(store.reload) { state in
			probe.isInsideTrigger = true
			defer { probe.isInsideTrigger = false }
			state.guides = nil
			state.isLoading = true
			store.addTask {
				let first = try await repository.page(offset: 0)
				try store.modify {
					$0.guides = first.guides
					$0.totalCount = first.totalCount
					$0.hasMore = first.guides.count < first.totalCount
					$0.isLoading = false
				}
			}
		}
	}
}

struct LibraryView: View {
	let store: StoreOf<Library>
	let probe: AppearanceProbe

	var body: some View {
		NavigationStack {
			GuideFeedView(store: store.spawn(\.feed), probe: probe)
				.navigationTitle("Downloaded guides")
				.toolbar {
					Button("Restore samples") {
						probe.reset()
						store.send(.restoreSamplesTapped)
					}
				}
		}
	}
}

private struct GuideFeedView: View {
	let store: StoreOf<GuideFeed>
	let probe: AppearanceProbe

	var body: some View {
		if let guides = store.guides {
			VStack {
				Text("Showing \(guides.count) of \(store.totalCount) downloads")
				ScrollView {
					LazyVStack(spacing: 12) {
						ForEach(guides) { guide in
							HStack {
								VStack(alignment: .leading, spacing: 8) {
									Text(guide.city).font(.title2.bold())
									Text(guide.topic).font(.headline)
									Label("Available offline", systemImage: "book.closed")
										.font(.caption)
										.foregroundStyle(.secondary)
								}
								.frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
								Button("Remove", systemImage: "trash", role: .destructive) {
									store.send(.removeTapped(guide.id))
								}
								.labelStyle(.iconOnly)
								.accessibilityLabel("Remove \(guide.title)")
							}
							.padding()
							.background(.quaternary, in: .rect(cornerRadius: 12))
							.onAppear {
								probe.recordAppearance()
								store.send(.guideAppeared(guide.id))
							}
						}
						if !store.hasMore { Text("All guides loaded").padding() }
					}
					.padding()
				}
			}
		} else {
			ProgressView("Loading library…").frame(maxWidth: .infinity, maxHeight: .infinity)
		}
	}
}
