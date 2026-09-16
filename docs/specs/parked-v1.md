## Problem Statement

Drivers often lose the context needed to return to a car in a large parking facility. A GPS coordinate alone is unreliable in underground garages, and a photo in the library is hard to find later. Parked must let an iPhone user save a parking memory in seconds and recover it offline through a calm, native interface.

## Solution

Parked is an iPhone-only, iOS 26+ SwiftUI app that keeps one local active parking memory. A driver saves it immediately when parking, then may add a photo and concise parking details. The find-my-car view combines those recall cues with an approximate saved location, current straight-line distance, and an Apple Maps directions handoff when location and map services are available.

The app works without an account, backend, cloud sync, analytics, or background location tracking. Its user-facing product copy uses natural Latin-script Finglish.

## User Stories

1. As a driver, I want to understand Parked’s purpose from the empty state, so that I can save my car’s location without onboarding.
2. As a driver, I want to tap one primary action to park, so that saving a parking memory is fast.
3. As a driver, I want Parked to timestamp the parking memory at the moment I tap park, so that I know how long ago I parked.
4. As a driver, I want Parked to save the newest usable foreground location without making me wait, so that a slow location reading does not block me.
5. As a driver, I want Parked to accept a better location reading briefly after saving, so that the saved location can improve without changing when I parked.
6. As a driver, I want to save a manual parking memory when location is unavailable, so that an underground garage does not stop me from recording where I parked.
7. As a driver, I want a clear recovery action after a location failure, so that I can retry or save without a location.
8. As a driver, I want to add a floor, section, spot or column, landmark, and note only when useful, so that the flow stays quick.
9. As a driver, I want to take a parking photo, so that I can remember signs, columns, or nearby landmarks.
10. As a driver, I want to select a photo from my library, so that I can attach a photo I already took.
11. As a driver, I want to replace or remove the parking photo, so that the parking memory stays accurate.
12. As a driver, I want to edit all optional parking details after saving, so that I can correct or add context later.
13. As a driver, I want all parking details to be optional, so that I can finish saving after one tap.
14. As a driver, I want an active state after saving, so that the current parking memory is clear when I reopen the app.
15. As a driver, I want Parked to restore the active parking memory after relaunch, so that I do not lose it before returning to my car.
16. As a driver, I want to replace an existing active parking memory only after confirmation, so that I do not remove useful recall cues by accident.
17. As a driver, I want one active parking memory rather than a history list, so that the app stays focused on my current car.
18. As a driver, I want a Find My Car action, so that I can quickly enter the return flow.
19. As a driver, I want the find-my-car view to show my parking details and photo, so that I can use human-readable clues in a garage.
20. As a driver, I want Parked to update my straight-line distance while I view the return screen, so that I can tell whether I am getting closer.
21. As a driver, I want distance in meters and kilometers, so that nearby distances are easy to understand.
22. As a driver, I want Parked to show a saved location as approximate when accuracy is poor, so that I do not mistake it for indoor navigation.
23. As a driver, I want to see the saved pin and its uncertainty area on the map when available, so that I can orient myself honestly.
24. As a driver, I want Parked to keep my photo and parking details visible if current location fails, so that the return flow remains useful.
25. As a driver, I want Parked to keep my photo and parking details visible if map tiles cannot load, so that lack of connectivity does not erase the memory.
26. As a driver, I want to open Apple Maps for directions to a saved location estimate, so that the system navigation app handles routing.
27. As a driver, I want manual parking memories to open a recall-cues-only return flow, so that a missing coordinate does not look like an app error.
28. As a driver, I want to confirm `Mashineto peyda kardi?` before ending a parking memory, so that I do not remove it too early.
29. As a driver, I want ending a parking memory to remove it locally after confirmation, so that V1 does not accumulate parking history.
30. As a driver, I want location access only while I use parking or finding features, so that Parked does not track me in the background.
31. As a driver, I want permission requests to appear when I use the relevant feature, so that I understand why Parked requests them.
32. As a driver, I want all product copy in natural Latin-script Finglish, so that the app feels written for Iranian users.
33. As a driver, I want Parked to follow my system Light or Dark Mode setting, so that it fits the rest of my iPhone.
34. As a driver, I want Dynamic Type, VoiceOver, contrast, and non-color accuracy cues, so that I can use Parked with my accessibility settings.
35. As a driver, I want restrained haptic feedback after saving and before destructive actions, so that I receive confirmation without distraction.

## Implementation Decisions

- The app targets iOS 26+ and iPhone. It uses SwiftUI, SwiftData, Core Location, MapKit, UserNotifications only if a specific V1 need appears, and Apple Maps for route guidance.
- A single app-level parking state model is the test seam. It publishes the empty, saving, active, finding, editing, failure, and confirmation states that SwiftUI renders. It accepts deterministic location and persistence collaborators in tests without introducing a dependency-injection framework or repository layer.
- SwiftData persists one active parking memory. It stores the timestamp, optional location estimate with horizontal accuracy, optional parking photo, and optional parking details. Replacing or completing the memory deletes the prior record after confirmation.
- The app saves a parking memory immediately. A short, foreground-only location update window may replace the initial location estimate when it improves accuracy.
- Location access uses when-in-use authorization only. Parked never starts background location updates. The app accepts iOS approximate location and frames it as approximate.
- The parking details editor is a compact, optional sheet shared by initial post-save editing and later editing. It supports camera capture, photo-library selection, replacement, and removal.
- The find-my-car view requests current location only while visible. It calculates straight-line metric distance and stops updates when the view leaves the foreground.
- The map shows the saved point and, when relevant, its uncertainty area. It does not claim indoor positioning or offer custom turn-by-turn navigation.
- Apple Maps receives a directions handoff only when a saved location estimate exists. Missing connectivity affects map content and handoff availability, never locally persisted recall cues.
- Product copy uses Latin-script Finglish. System terminology may remain in English where that is more familiar. The app follows native SwiftUI navigation, system typography, system color behavior, and device appearance.
- The project does not add accounts, authentication, networking, cloud sync, social features, parking history, a tab bar, analytics, widgets, Live Activities, Siri, Apple Watch support, or background parking detection in V1.

## Testing Decisions

- Tests verify user-visible state and outcomes through the app-level parking state model. They do not assert SwiftUI layout internals, SwiftData implementation calls, or Core Location delegate mechanics.
- Unit tests cover parking-memory creation, editing, replacement, completion, restoration, manual-memory fallback, location quality selection, distance presentation, and permission or location failure states.
- The persistence test configuration uses an in-memory SwiftData container. Location tests use deterministic samples for accurate, approximate, unavailable, and improved readings.
- UI tests cover the empty-to-active flow, optional detail editing, active-memory replacement confirmation, manual-memory finding, completion confirmation, Dynamic Type behavior, and VoiceOver-facing labels or actions where UI automation can inspect them.
- Real-iPhone checks cover location permission timing, approximate-location behavior, camera and photo-picker behavior, MapKit rendering, Apple Maps handoff, Dark Mode, and haptic feedback.

## Out of Scope

- iPad, iOS versions earlier than 26, Android, and other platforms.
- Accounts, authentication, backend services, cloud sync, analytics, social features, and networking beyond Apple system map services.
- Background location tracking, automatic parking detection, indoor positioning, custom navigation, offline map tiles, and offline routing.
- Parking history, favorite facilities, multi-device support, widgets, Lock Screen widgets, Live Activities, App Intents, Siri, and Apple Watch support.
- Notifications in V1. The product has no specific reminder moment that justifies one.

## Further Notes

- The quality bar is practical: a driver should find their car more easily than by searching through random photos.
- The saved location estimate is supporting context. Parking details and the parking photo are first-class recall cues.
- The app should feel like a small native iOS utility, not a dashboard or a branded design exercise.
