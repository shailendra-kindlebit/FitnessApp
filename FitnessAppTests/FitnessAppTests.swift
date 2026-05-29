//
//  FitnessAppTests.swift
//  FitnessAppTests
//

import Foundation
import Testing
@testable import FitnessApp

struct FitnessAppTests {
    @Test func snapshotFormatsDashboardMetrics() {
        let snapshot = FitnessSnapshot(
            steps: 12_345,
            activeEnergy: 420,
            distance: 3_260,
            heartRate: 72,
            workouts: [],
            lastUpdated: Date(timeIntervalSince1970: 0)
        )

        #expect(snapshot.metrics.count == 4)
        #expect(snapshot.metrics[0].value == "12,345")
        #expect(snapshot.metrics[1].value == "420")
        #expect(snapshot.metrics[2].value == "3.3")
        #expect(snapshot.metrics[3].value == "72")
        #expect(snapshot.moveProgress == 0.7)
    }

    @Test func snapshotProgressCapsAtGoal() {
        let snapshot = FitnessSnapshot(
            steps: 22_000,
            activeEnergy: 900,
            distance: 0,
            heartRate: nil,
            workouts: [],
            lastUpdated: Date(timeIntervalSince1970: 0)
        )

        #expect(snapshot.stepProgress == 1)
        #expect(snapshot.moveProgress == 1)
        #expect(snapshot.metrics[3].value == "--")
    }

    @Test func liveWorkoutStateRoundTripsThroughDictionary() {
        let state = LiveWorkoutState(
            heartRate: 142,
            activeEnergy: 180,
            distance: 1_250,
            elapsedTime: 600,
            state: "running",
            startedAt: Date(timeIntervalSince1970: 100),
            updatedAt: Date(timeIntervalSince1970: 700),
            sequence: 12
        )

        let decoded = LiveWorkoutState(dictionary: state.dictionary)

        #expect(decoded == state)
    }
}
