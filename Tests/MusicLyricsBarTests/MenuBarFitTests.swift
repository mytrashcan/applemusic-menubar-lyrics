import Foundation
import Testing
@testable import MusicLyricsBar

struct StatusItemPlacementTests {
    private let notchRegionMinX: CGFloat = 947.5
    private let visibleFrame = CGRect(x: 1022, y: 1073, width: 256, height: 34)

    @Test func visibleWindowIsNeverClipped() {
        let placement = StatusItemPlacement(isOccluded: false, frame: visibleFrame, hasScreen: true,
                                            visibleRegionMinX: notchRegionMinX, lastVisibleFrame: nil)
        #expect(!placement.isClipped)
    }

    @Test func itemParkedWithoutAScreenIsClipped() {
        // macOS parks an item it never placed at (0, -34) with no screen.
        let placement = StatusItemPlacement(isOccluded: true, frame: CGRect(x: 0, y: -34, width: 166, height: 34),
                                            hasScreen: false, visibleRegionMinX: nil, lastVisibleFrame: nil)
        #expect(placement.isClipped)
        #expect(StatusItemPlacement(isOccluded: true, frame: nil, hasScreen: false,
                                    visibleRegionMinX: nil, lastVisibleFrame: nil).isClipped)
    }

    @Test func occludedItemLeftOfTheNotchRegionIsClipped() {
        let pushedOut = StatusItemPlacement(isOccluded: true, frame: CGRect(x: 654, y: 1073, width: 616, height: 34),
                                            hasScreen: true, visibleRegionMinX: notchRegionMinX, lastVisibleFrame: nil)
        #expect(pushedOut.isClipped)
        // A full-screen app hides the menu bar: occluded, but the frame stays in the visible region.
        let menuBarHidden = StatusItemPlacement(isOccluded: true, frame: visibleFrame, hasScreen: true,
                                                visibleRegionMinX: notchRegionMinX, lastVisibleFrame: visibleFrame)
        #expect(!menuBarHidden.isClipped)
    }

    @Test func occludedItemRightOfTheNotchIsClippedWhenItMovedOrWasNeverSeen() {
        // Observed on a crowded bar: a 200pt item parked at x 951, just right of the region start, yet occluded.
        let parked = CGRect(x: 951, y: 1073, width: 216, height: 34)
        let unseen = StatusItemPlacement(isOccluded: true, frame: parked, hasScreen: true,
                                         visibleRegionMinX: notchRegionMinX, lastVisibleFrame: nil)
        #expect(unseen.isClipped)
        let iconWasVisible = CGRect(x: 1240, y: 1073, width: 38, height: 34)
        let moved = StatusItemPlacement(isOccluded: true, frame: parked, hasScreen: true,
                                        visibleRegionMinX: notchRegionMinX, lastVisibleFrame: iconWasVisible)
        #expect(moved.isClipped)
        // Our own resize in the same slot keeps the right edge: still the hidden-menu-bar case.
        let resized = StatusItemPlacement(isOccluded: true, frame: CGRect(x: 1062, y: 1073, width: 216, height: 34),
                                          hasScreen: true, visibleRegionMinX: notchRegionMinX, lastVisibleFrame: iconWasVisible)
        #expect(!resized.isClipped)
    }

    @Test func withoutANotchAMovedRightEdgeMeansClipped() {
        let hiddenBar = StatusItemPlacement(isOccluded: true, frame: visibleFrame, hasScreen: true,
                                            visibleRegionMinX: nil, lastVisibleFrame: visibleFrame)
        #expect(!hiddenBar.isClipped)
        // Our own resize keeps the right edge; a relocation by macOS does not.
        let resized = StatusItemPlacement(isOccluded: true, frame: CGRect(x: 1240, y: 1073, width: 38, height: 34),
                                          hasScreen: true, visibleRegionMinX: nil, lastVisibleFrame: visibleFrame)
        #expect(!resized.isClipped)
        let moved = StatusItemPlacement(isOccluded: true, frame: CGRect(x: 654, y: 1073, width: 616, height: 34),
                                        hasScreen: true, visibleRegionMinX: nil, lastVisibleFrame: visibleFrame)
        #expect(moved.isClipped)
        // No reference frame yet: assume the worst so the item at least shows its icon.
        let unknown = StatusItemPlacement(isOccluded: true, frame: visibleFrame, hasScreen: true,
                                          visibleRegionMinX: nil, lastVisibleFrame: nil)
        #expect(unknown.isClipped)
    }
}

struct MenuBarFitPolicyTests {
    private let settle = MenuBarFitPolicy.settleInterval
    private let retry = MenuBarFitPolicy.initialRetryInterval

    @Test func startsAtThePreferredWidthAndDoesNothingWhileVisible() {
        var policy = MenuBarFitPolicy(preferred: .wide)
        #expect(policy.length == LyricsWidth.wide.points)
        #expect(!policy.isReduced)
        #expect(policy.update(clipped: false, now: 0) == .init())
        #expect(policy == MenuBarFitPolicy(preferred: .wide))
    }

    @Test func stepsDownThroughTheWidthsToTheIconAndStopsThere() {
        var policy = MenuBarFitPolicy(preferred: .wide)
        #expect(policy.update(clipped: true, now: 0) == .init(length: LyricsWidth.medium.points, checkAfter: settle))
        #expect(policy.update(clipped: true, now: 1) == .init(length: LyricsWidth.narrow.points, checkAfter: settle))
        #expect(policy.update(clipped: true, now: 2) == .init(length: LyricsWidth.compact.points, checkAfter: settle))
        #expect(policy.update(clipped: true, now: 3) == .init(length: MenuBarFitPolicy.iconOnlyLength, checkAfter: settle))
        #expect(policy.isIconOnly)
        #expect(policy.level == .iconOnly)
        // Nothing smaller to try: wait for the window to become visible again.
        #expect(policy.update(clipped: true, now: 4) == .init())
    }

    @Test func compactPreferenceGoesStraightToTheIcon() {
        var policy = MenuBarFitPolicy(preferred: .compact)
        #expect(policy.update(clipped: true, now: 0).length == MenuBarFitPolicy.iconOnlyLength)
        #expect(policy.level == .iconOnly)
    }

    @Test func growsBackOneStepAtATimeOnceTheRetryIsDue() {
        var policy = MenuBarFitPolicy(preferred: .medium)
        _ = policy.update(clipped: true, now: 0)
        _ = policy.update(clipped: true, now: 1)
        #expect(policy.level == .width(.compact))
        // Visible again, but the retry scheduled at the last shrink is not due yet.
        #expect(policy.update(clipped: false, now: 2) == .init(checkAfter: retry - 1))
        #expect(policy.update(clipped: false, now: 1 + retry) == .init(length: LyricsWidth.narrow.points, checkAfter: settle))
        #expect(policy.update(clipped: false, now: 1 + retry + settle) == .init(checkAfter: retry - settle))
        #expect(policy.update(clipped: false, now: 1 + 2 * retry) == .init(length: LyricsWidth.medium.points, checkAfter: settle))
        #expect(!policy.isReduced)
        #expect(policy.update(clipped: false, now: 1 + 2 * retry + settle) == .init())
    }

    @Test func failedProbesBackOffExponentiallyUpToTheMaximum() {
        var policy = MenuBarFitPolicy(preferred: .narrow)
        _ = policy.update(clipped: true, now: 0)
        var now = retry
        var delays: [TimeInterval] = []
        for _ in 0..<7 {
            #expect(policy.update(clipped: false, now: now).length == LyricsWidth.narrow.points)
            // Clipped right after growing: a failed probe.
            let decision = policy.update(clipped: true, now: now + 0.5)
            #expect(decision.length == LyricsWidth.compact.points)
            guard case .some(let wait) = policy.update(clipped: false, now: now + 1).checkAfter else {
                Issue.record("Expected a scheduled retry"); return
            }
            // The clip happened half a second after the grow; the wait reported at now + 1 is the
            // new interval minus that half second.
            delays.append(wait + 0.5)
            now += wait + 1
        }
        #expect(delays == [40, 80, 160, 320, 600, 600, 600])
    }

    @Test func aSurvivingGrowResetsTheBackoff() {
        var policy = MenuBarFitPolicy(preferred: .medium)
        _ = policy.update(clipped: true, now: 0)
        _ = policy.update(clipped: true, now: 1)
        _ = policy.update(clipped: false, now: 1 + retry)          // grow to narrow
        _ = policy.update(clipped: true, now: 2 + retry)           // fails: interval doubles to 40
        let failedWait = policy.update(clipped: false, now: 3 + retry).checkAfter ?? 0
        #expect(failedWait == 2 * retry - 1)
        let secondGrow = 2 + retry + 2 * retry
        #expect(policy.update(clipped: false, now: secondGrow).length == LyricsWidth.narrow.points)
        // It survives the probe window this time, so the next step waits the initial interval again.
        #expect(policy.update(clipped: false, now: secondGrow + 2 * retry).length == LyricsWidth.medium.points)
        _ = policy.update(clipped: true, now: secondGrow + 2 * retry + 100)  // external hide, not a probe
        #expect(policy.update(clipped: false, now: secondGrow + 2 * retry + 101).checkAfter == retry - 1)
    }

    @Test func screenChangeProbesSoonAndForgetsTheBackoff() {
        var policy = MenuBarFitPolicy(preferred: .narrow)
        #expect(policy.screenChanged(now: 0) == .init())
        _ = policy.update(clipped: true, now: 0)
        #expect(policy.screenChanged(now: 5) == .init(checkAfter: MenuBarFitPolicy.screenChangeDelay))
        #expect(policy.update(clipped: false, now: 5 + MenuBarFitPolicy.screenChangeDelay).length == LyricsWidth.narrow.points)
    }
}
