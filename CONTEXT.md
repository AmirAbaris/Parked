# Parked

Parked helps a driver save enough context about where they left a car to return to it. It is designed for locations where a coordinate alone may be unreliable.

## Language

**Parking memory**:
The saved record of one parking event, including its approximate location and human-readable recall cues such as a photo, floor, section, spot, landmark, or note.
_Avoid_: Parking pin, saved location

**Active parking memory**:
The one parking memory the driver is currently using to return to their car. Ending it removes the memory after the driver confirms.
_Avoid_: Parking history item, parked car

**Parking memory replacement**:
The confirmed removal of an active parking memory when the driver saves a new one. Parked has no parking history in V1.
_Avoid_: New parking session, overwrite

**Parking details**:
The optional human-readable fields within a parking memory that identify a vehicle's place in a parking facility: floor, section, spot or column, landmark, and note.
_Avoid_: Metadata, parking data

**Parking photo**:
An optional image attached to a parking memory, captured with the camera or selected from the photo library.
_Avoid_: Receipt, gallery image

**Location estimate**:
The device location saved with a parking memory when one is available. It may be inaccurate and never substitutes for parking details.
_Avoid_: Exact location, parking coordinate

**Manual parking memory**:
A parking memory saved without a usable device location. It supports the same photo and parking details as a location-backed memory.
_Avoid_: Offline mode, location-free session

**Finglish copy**:
User-facing Persian written in Latin characters, phrased as Iranian speakers naturally message rather than translated word-for-word from English.
_Avoid_: Romanized Persian, transliterated UI

**Directions handoff**:
The action that opens Apple Maps with the saved approximate location as its destination. Parked shows the parking memory and map context before this handoff.
_Avoid_: In-app navigation, route guidance

**Find-my-car view**:
The screen for returning to an active parking memory. With a location estimate, it shows distance, an approximate map, and directions handoff; without one, it shows recall cues only.
_Avoid_: Navigation screen, route screen

**Parking memory completion**:
The driver's confirmed removal of an active parking memory after finding the car.
_Avoid_: Session close, archive

**Offline memory access**:
The ability to save and read parking memories without network connectivity. Map tiles and directions handoff may be unavailable offline, but recall cues remain available.
_Avoid_: Offline maps, offline navigation

**Live return distance**:
The straight-line metric distance between the driver's current foreground location and a parking memory's location estimate. It is unavailable when either location is missing.
_Avoid_: Navigation distance, route distance

**System-native visual language**:
An iPhone interface that uses familiar SwiftUI navigation, controls, spacing, typography, and system Light and Dark Mode behavior. Parked's blue-and-white mark is limited to app-identity surfaces such as the app icon and root header; it does not become a separate visual theme.
_Avoid_: Branded design system, custom theme
