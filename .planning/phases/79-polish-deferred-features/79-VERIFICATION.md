# Phase 79 Verification

## Build Status
BUILD SUCCEEDED — Xcode simulator build for iPhone 17 (iOS 26.5)

## POL-01: Debug tab split
- [ ] Navigate to More > Developer > Debug
- [ ] Verify TabView with "Status", "Capture", "Research" tabs is shown
- [ ] Status tab: connection device row present, Rust/parser info, data provenance
- [ ] Capture tab: health packet capture rows, movement test, event signals
- [ ] Research tab: research BT commands, diagnostics, developer (DEBUG) options
- [ ] Connection row appears exactly once (in Status tab)

## POL-02: More nav reorganisation
- [ ] More screen: "Support" section shows only "About"
- [ ] More screen: "Developer" section shows "Logs & Export" and "Developer"
- [ ] Tapping "Logs & Export" navigates to MoreSupportView (existing destination)
- [ ] Tapping "Developer" navigates to MoreDeveloperView (existing destination)

## DEF-01: BreatheView haptics
- [ ] Start a Breathe session with WHOOP connected
- [ ] Verify haptic buzz at start of Inhale, Hold, Exhale phases
- [ ] No buzz on Stop

## DEF-02: Live workout strain
- [ ] Start a workout with WHOOP connected
- [ ] HR data flowing
- [ ] Strain tile in active workout screen updates within 3 seconds of HR samples arriving
