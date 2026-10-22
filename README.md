# TCA26 onAppear reentrancy

Minimal iOS app for [TCA26 #241](https://github.com/pointfreeco/TCA26/issues/241), using real SwiftUI `onAppear` callbacks.

## Run

You need access to the TCA26 GitHub repository. Configure GitHub authentication in Xcode so it can resolve the package dependency.

1. Open `OnAppearReentrancy.xcodeproj` in Xcode 27.1 with Swift 6.4.
2. Select the **OnAppearReentrancy** scheme and an **iPhone 17** simulator with **iOS 27.0**. Run in **Debug**.
3. Tap **Run synchronous**. Expect **REPRODUCED**, a callback inside the trigger, and a reentrancy diagnostic.
4. Tap **Run deferred control**. Expect **CONTROL PASSED** and a callback inside the trigger. Its deferred action reaches the action handler after the trigger exits, without a diagnostic.

The app keeps IssueReporting's default runtime reporter and also displays counters. The diagnostic and captured stack are printed to the Xcode console:

```text
Can't send another action before handling this one; if you need to send an action in response, enqueue it asynchronously via 'store.addTask { try store.send(action) }'
```

## Mechanism

Each button mounts a fresh `UIHostingController` containing a `ScrollView` and `LazyVStack`, lays it out, then immediately sends a deletion action. Its task animates removal of one row and calls a trigger that clears the remaining rows. During that mutation, SwiftUI dispatches a pending `onAppear`, which sends an action back into the store.

The control changes only that send to `Task { @MainActor in ... }`. A non-observable probe records when the callback enters and when its deferred action reaches the action handler. The list clears immediately, so read the counters for the result.

This exercises pending initial appearances, not deletion from a settled list. It uses no sleeps or synthetic Observation callbacks.

## Verified configuration

- Xcode 27.1, Swift 6.4; iPhone 17 simulator, iOS 27.0 (`24A434`).
- TCA26 pinned to `af4898ab7ae8f24caa1014c0b269d76be9e17182`, which includes #278's runtime diagnostic.
- Simulator verification: synchronous reported the diagnostic; deferred recorded one callback inside the trigger and one action afterward, without diagnostics.
