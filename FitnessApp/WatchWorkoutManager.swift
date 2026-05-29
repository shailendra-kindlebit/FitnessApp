//
//  WatchWorkoutManager.swift
//  FitnessApp
//

#if os(watchOS)

import Foundation
import HealthKit
import Observation

@MainActor
@Observable
final class WatchWorkoutManager: NSObject {
    private let healthStore = HKHealthStore()
    private let watchSessionManager: WatchSessionManager

    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var startDate: Date?
    private var lastTransmittedSequence = 0
    private var lastTransmitDate = Date.distantPast

    var liveState = LiveWorkoutState()
    var errorMessage: String?
    var isWorkoutRunning = false

    init(watchSessionManager: WatchSessionManager = WatchSessionManager()) {
        self.watchSessionManager = watchSessionManager
        super.init()
    }

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitManagerError.healthDataUnavailable
        }

        let typesToShare: Set<HKSampleType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]

        let typesToRead: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceWalkingRunning)
        ]

        try await healthStore.requestAuthorization(toShare: typesToShare, read: typesToRead)
    }

    func startWorkout(activityType: HKWorkoutActivityType = .running, locationType: HKWorkoutSessionLocationType = .outdoor) async {
        do {
            try await requestAuthorization()
            cleanupSessionObjects()

            let configuration = HKWorkoutConfiguration()
            configuration.activityType = activityType
            configuration.locationType = locationType

            let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
            let builder = session.associatedWorkoutBuilder()
            builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: configuration)
            session.delegate = self
            builder.delegate = self

            let startedAt = Date()
            self.session = session
            self.builder = builder
            self.startDate = startedAt
            self.liveState = LiveWorkoutState(state: "running", startedAt: startedAt, updatedAt: startedAt)
            self.isWorkoutRunning = true
            self.errorMessage = nil

            session.startActivity(with: startedAt)
            try await builder.beginCollection(at: startedAt)
            transmitLiveState(force: true)
        } catch {
            errorMessage = error.localizedDescription
            isWorkoutRunning = false
            cleanupSessionObjects()
        }
    }

    func pauseWorkout() {
        session?.pause()
        liveState.state = "paused"
        liveState.updatedAt = Date()
        transmitLiveState(force: true)
    }

    func resumeWorkout() {
        session?.resume()
        liveState.state = "running"
        liveState.updatedAt = Date()
        transmitLiveState(force: true)
    }

    func endWorkout() {
        liveState.state = "ending"
        liveState.updatedAt = Date()
        transmitLiveState(force: true)
        session?.end()
    }

    private func finishWorkout() async {
        guard let builder else {
            cleanupSessionObjects()
            return
        }

        do {
            _ = try await builder.endCollection(at: Date())
            _ = try await builder.finishWorkout()
            liveState.state = "ended"
            liveState.updatedAt = Date()
            transmitLiveState(force: true)
        } catch {
            errorMessage = error.localizedDescription
        }

        isWorkoutRunning = false
        cleanupSessionObjects()
    }

    private func updateStatistics(for quantityType: HKQuantityType) {
        guard let builder else { return }
        let statistics = builder.statistics(for: quantityType)

        switch quantityType.identifier {
        case HKQuantityTypeIdentifier.heartRate.rawValue:
            let unit = HKUnit.count().unitDivided(by: .minute())
            liveState.heartRate = statistics?.mostRecentQuantity()?.doubleValue(for: unit)
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue:
            liveState.activeEnergy = statistics?.sumQuantity()?.doubleValue(for: .largeCalorie()) ?? liveState.activeEnergy
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue:
            liveState.distance = statistics?.sumQuantity()?.doubleValue(for: .meter()) ?? liveState.distance
        default:
            break
        }

        if let startDate {
            liveState.elapsedTime = Date().timeIntervalSince(startDate)
        }

        liveState.updatedAt = Date()
        transmitLiveState(force: false)
    }

    private func transmitLiveState(force: Bool) {
        let now = Date()
        guard force || now.timeIntervalSince(lastTransmitDate) >= 1 else {
            return
        }

        lastTransmitDate = now
        lastTransmittedSequence += 1
        liveState.sequence = lastTransmittedSequence
        watchSessionManager.send(workoutState: liveState)
    }

    private func cleanupSessionObjects() {
        session?.delegate = nil
        builder?.delegate = nil
        session = nil
        builder = nil
        startDate = nil
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        Task { @MainActor in
            self.liveState.state = toState.syncStateName
            self.liveState.updatedAt = date
            self.transmitLiveState(force: true)

            if toState == .ended {
                await self.finishWorkout()
            }
        }
    }

    nonisolated func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
            self.liveState.state = "failed"
            self.liveState.updatedAt = Date()
            self.transmitLiveState(force: true)
            self.isWorkoutRunning = false
            self.cleanupSessionObjects()
        }
    }
}

extension WatchWorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
        Task { @MainActor in
            for sampleType in collectedTypes {
                guard let quantityType = sampleType as? HKQuantityType else { continue }
                self.updateStatistics(for: quantityType)
            }
        }
    }

    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {
        Task { @MainActor in
            self.liveState.updatedAt = Date()
            self.transmitLiveState(force: true)
        }
    }
}

private extension HKWorkoutSessionState {
    var syncStateName: String {
        switch self {
        case .notStarted:
            "notStarted"
        case .running:
            "running"
        case .ended:
            "ended"
        case .paused:
            "paused"
        case .prepared:
            "prepared"
        case .stopped:
            "stopped"
        @unknown default:
            "unknown"
        }
    }
}

#endif
