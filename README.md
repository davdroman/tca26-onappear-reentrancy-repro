# TCA26 onAppear reentrancy

Standalone iOS reproduction for [TCA26 #241](https://github.com/pointfreeco/TCA26/issues/241). In the verified configuration below, removing a download from a settled, paginated list causes a SwiftUI `onAppear` callback to send an action during a TCA trigger mutation.

## Run

You need access to the TCA26 GitHub repository. Configure GitHub authentication in Xcode so it can resolve the package dependency.

1. Open `OnAppearReentrancy.xcodeproj` in Xcode 27.1 with Swift 6.4.
2. Select the **OnAppearReentrancy** scheme and an **iPhone 17** simulator with **iOS 27.0**. Run in **Debug**.
3. Leave **Synchronous** selected and wait for **Downloaded guides** to finish loading. To start with the original data, tap **Restore samples** and wait for **Showing 12 of 60 downloads** and the list to settle.
4. Tap the first visible trash button, beside **Lisbon**, **Neighborhood walks**. The download disappears and the total decreases to 59. Expect one callback inside the trigger, one diagnostic, and a captured trigger + SwiftUI stack.
5. Select **Deferred control**, tap **Restore samples**, and wait for the list to settle again. Remove the same download. Expect one callback inside the trigger, one deferred action afterward, and zero diagnostics.

Counters reset on each removal and sample restore. To test pagination separately, scroll toward the end of the loaded rows to fetch another page. Restore samples before comparing the two modes.

The app keeps IssueReporting's default runtime reporter and also displays counters. The diagnostic and captured stack are printed to the Xcode console:

```text
Can't send another action before handling this one; if you need to send an action in response, enqueue it asynchronously via 'store.addTask { try store.send(action) }'
```

## Mechanism

Restoring samples writes 60 download records to `Documents/guides.json`. An actor reads pages of 12 records from disk. Rows in a `LazyVStack` inside a `ScrollView` send appearance actions. When any of the last six loaded rows appears, the action requests the next page if another page exists and no load is in progress.

Removing a download writes the file, animates local row removal, and posts an event from the spawned feed to its parent. The parent invokes the feed's `reload` trigger to reconcile the paginated list with the updated file. That trigger sets `guides` to `nil`, replacing the results with a loading view, then asynchronously rereads the first page and total count.

The captured warning occurs during the trigger's `guides = nil` mutation. Observation invalidation dispatches a SwiftUI row appearance, whose synchronous `Store.send` encounters the reentrancy check. The stack includes `OnTriggerModifier`, the `GuideFeed.State.guides` setter, `ObservationCenter.invalidate`, `_AppearanceActionModifier`, the row's `onAppear`, and `SpawnedCore.send`.

The control changes only the appearance action's delivery to `Task { @MainActor in ... }`. A non-observable probe records callback entry during the trigger and action delivery after the trigger exits. The hosting controller persists throughout the reproduction, but the reload replaces the results list with a loading view. The app uses no forced layout, sleeps, or synthetic appearance callbacks.

## Verified configuration

- Xcode 27.1, Swift 6.4, iPhone 17 simulator, iOS 27.0 (`24A434`).
- TCA26 pinned to `af4898ab7ae8f24caa1014c0b269d76be9e17182`, which includes #278's runtime diagnostic.
- Three successive settled-list removals in synchronous mode each recorded one callback inside the trigger and one diagnostic. After restoring samples, the same three removals in deferred mode each recorded one callback inside the trigger, one action afterward, and zero diagnostics. Both sequences decreased the total from 60 to 57.
- Scrolling loaded a second page, advancing the displayed count from 12 to 24 of 60 downloads.

These results cover the steps and simulator configuration above; other devices, OS versions, and scroll positions have not been established.
