import Foundation
import Testing
import LyricsCore
@testable import MusicLyricsBar

struct PollSchedulerTests {
    private let track = Track(id: "t", title: "Synthetic", artist: "Test", album: "", duration: 30)
    private func sample(playing: Bool) -> PlaybackSample {
        PlaybackSample(track: track, position: 1, isPlaying: playing, sampledAt: 0)
    }

    @Test func startsOneReadAndCoalescesRequestsWhileItRuns() {
        var scheduler = PollScheduler()
        #expect(scheduler.request(refreshMetadata: false) == false)
        #expect(scheduler.isPolling)
        #expect(scheduler.request(refreshMetadata: false) == nil)
        #expect(scheduler.request(refreshMetadata: true) == nil)
        #expect(scheduler.finish(sample: sample(playing: true), failed: false) == .pollNow)
        // The coalesced request carries the metadata refresh that was asked for meanwhile.
        #expect(scheduler.request(refreshMetadata: false) == true)
        #expect(scheduler.finish(sample: sample(playing: true), failed: false) == .wait(PollScheduler.playingInterval))
    }

    @Test func idlesSlowlyWhenMusicIsAbsentOrPaused() {
        var scheduler = PollScheduler()
        _ = scheduler.request(refreshMetadata: true)
        #expect(scheduler.finish(sample: nil, failed: false) == .wait(PollScheduler.idleInterval))
        _ = scheduler.request(refreshMetadata: false)
        #expect(scheduler.finish(sample: sample(playing: false), failed: false) == .wait(PollScheduler.pausedInterval))
    }

    @Test func backsOffAfterRepeatedFailuresAndRecoversOnSuccess() {
        var scheduler = PollScheduler()
        var delays: [TimeInterval] = []
        for _ in 0..<7 {
            _ = scheduler.request(refreshMetadata: false)
            guard case .wait(let delay) = scheduler.finish(sample: nil, failed: true) else { Issue.record("Expected a wait"); return }
            delays.append(delay)
        }
        #expect(delays == [0.5, 1, 2, 4, 8, 10, 10])
        _ = scheduler.request(refreshMetadata: false)
        #expect(scheduler.finish(sample: sample(playing: true), failed: false) == .wait(PollScheduler.playingInterval))
        _ = scheduler.request(refreshMetadata: false)
        #expect(scheduler.finish(sample: nil, failed: true) == .wait(PollScheduler.failureInterval))
    }

    @Test func resetForgetsInFlightAndPendingState() {
        var scheduler = PollScheduler()
        _ = scheduler.request(refreshMetadata: true)
        _ = scheduler.request(refreshMetadata: true)
        scheduler.reset()
        #expect(scheduler == PollScheduler())
        #expect(scheduler.request(refreshMetadata: false) == false)
    }
}

struct CacheRescanPolicyTests {
    private let stampA = MusicCacheStamp(entries: ["Cache.db": .init(modified: Date(timeIntervalSince1970: 1), size: 10)])
    private let stampB = MusicCacheStamp(entries: ["Cache.db": .init(modified: Date(timeIntervalSince1970: 2), size: 10)])

    @Test func scansOnceThenOnlyWhenTheCacheChangesOrTheSafetyIntervalPasses() {
        var policy = CacheRescanPolicy()
        #expect(policy.shouldScan(stamp: stampA, now: 100))
        policy.recordMiss(stamp: stampA, now: 100)
        #expect(!policy.shouldScan(stamp: stampA, now: 103))
        #expect(!policy.shouldScan(stamp: stampA, now: 100 + CacheRescanPolicy.fullScanInterval - 1))
        #expect(policy.shouldScan(stamp: stampB, now: 103))
        #expect(policy.shouldScan(stamp: stampA, now: 100 + CacheRescanPolicy.fullScanInterval))
    }

    @Test func missingCacheStillRetriesOnTheSafetyInterval() {
        var policy = CacheRescanPolicy()
        #expect(policy.shouldScan(stamp: nil, now: 0))
        policy.recordMiss(stamp: nil, now: 0)
        #expect(!policy.shouldScan(stamp: nil, now: 30))
        #expect(policy.shouldScan(stamp: stampA, now: 30))
        #expect(policy.shouldScan(stamp: nil, now: CacheRescanPolicy.fullScanInterval))
        policy.reset()
        #expect(policy.shouldScan(stamp: nil, now: 1))
    }
}
