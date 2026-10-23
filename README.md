# TCA26 onAppear reentrancy

Standalone iOS reproduction for [TCA26 #241](https://github.com/pointfreeco/TCA26/issues/241). In the pre-migration UI verification described below, removing a download from a settled, paginated list caused a SwiftUI `onAppear` callback to send an action during a TCA trigger mutation.

## Run

You need access to the TCA26 GitHub repository. Configure GitHub authentication in Xcode so it can resolve the package dependency.

1. Open `OnAppearReentrancy.xcodeproj` in Xcode 27.2 RC (`27B48`), which includes Swift 6.4.2 and was used to build the current project format. Earlier Xcode compatibility has not been verified for this format.
2. Select the **OnAppearReentrancy** scheme and an **iPhone 17** simulator with **iOS 27.0**. Run in **Debug**.
3. Wait for **Downloaded guides** to finish loading. Tap **Restore samples** and wait for the list to settle. In the verified simulator layout, appearance-driven pagination loads 24 records before scrolling, and the app displays **Showing 24 of 60 downloads**.
4. Tap the first visible trash button, beside **Lisbon**, **Neighborhood walks**. The download disappears and the total decreases to 59. Expect one callback inside the trigger and one diagnostic.

Counters reset on each removal and sample restore. To test pagination separately, scroll toward the end of the loaded rows to fetch another page. Restore samples and wait for the list to settle before repeating the removal.

The app keeps IssueReporting's default runtime reporter and displays callback and diagnostic counts. TCA reports this runtime warning:

```text
Can't send another action before handling this one; if you need to send an action in response, enqueue it asynchronously via 'store.addTask { try store.send(action) }'
```

## Mechanism

Restoring samples writes 60 download records to `Documents/guides.json`. An actor reads pages of 12 records from disk. Rows in a `LazyVStack` inside a `ScrollView` send appearance actions. When any of the last six loaded rows appears, the action requests the next page if another page exists and no load is in progress.

Removing a download writes the file, animates local row removal, and posts an event from the spawned feed to its parent. The parent invokes the feed's `reload` trigger to reconcile the paginated list with the updated file. That trigger sets `guides` to `nil`, replacing the results with a loading view, then asynchronously rereads the first page and total count.

The warning occurs during the trigger's `guides = nil` mutation. Observation invalidation dispatches a SwiftUI row appearance, whose synchronous `Store.send` encounters the reentrancy check.

A non-observable probe records callback entry during the trigger. The hosting controller persists throughout the reproduction, but the reload replaces the results list with a loading view. The app uses no forced layout, sleeps, or synthetic appearance callbacks.

## Verification

- The migrated project built successfully with Xcode 27.2 RC (`27B48`), Swift 6.4.2, for a generic iOS Simulator destination. This was a build check, not a new UI test.
- TCA26 pinned to `af4898ab7ae8f24caa1014c0b269d76be9e17182`, which includes #278's runtime diagnostic.

The following UI results were recorded before the project-format migration, using Xcode 27.1, Swift 6.4, and an iPhone 17 simulator running iOS 27.0 (`24A434`):

- Three successive settled-list removals each recorded one callback inside the trigger and one diagnostic, decreasing the total from 60 to 57.
- The settled list loaded 24 records through appearance-driven pagination. After the three removals, scrolling loaded another page, advancing the displayed count from 24 to 36 of 57 downloads.

The current app has been manually tested.

The recorded UI results cover the steps above in the pre-migration Xcode 27.1 configuration. Results on other devices, OS versions, and scroll positions have not been established.
