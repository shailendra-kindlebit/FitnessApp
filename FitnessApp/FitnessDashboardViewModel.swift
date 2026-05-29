//
//  FitnessDashboardViewModel.swift
//  FitnessApp
//

import Foundation
import Observation

@MainActor
@Observable
final class FitnessDashboardViewModel {
    private let healthKitManager: HealthKitManager
    private let watchSessionManager: WatchSessionManager

    var snapshot: FitnessSnapshot = .empty
    var liveWorkoutState: LiveWorkoutState?
    var isLoading = false
    var hasRequestedAccess = false
    var errorMessage: String?
    private var watchConnectionState: WatchConnectionState = .unavailable

    init(
        healthKitManager: HealthKitManager? = nil,
        watchSessionManager: WatchSessionManager? = nil
    ) {
        self.healthKitManager = healthKitManager ?? HealthKitManager()
        self.watchSessionManager = watchSessionManager ?? WatchSessionManager()
        self.watchConnectionState = self.watchSessionManager.connectionState

        self.watchSessionManager.onLiveWorkoutUpdate = { [weak self] state in
            Task { @MainActor in
                self?.applyLiveWorkoutState(state)
            }
        }

        self.watchSessionManager.onConnectionStateChange = { [weak self] state in
            Task { @MainActor in
                self?.watchConnectionState = state
            }
        }
    }

    var watchConnectionTitle: String {
        watchConnectionState.title
    }

    var canRequestHealthAccess: Bool {
        healthKitManager.isHealthDataAvailable
    }

    func requestAccessAndRefresh() async {
        isLoading = true
        errorMessage = nil

        do {
            try await healthKitManager.requestAuthorization()
            hasRequestedAccess = true
            try await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    func refresh() async throws {
        let loadedSnapshot = try await healthKitManager.loadTodaySnapshot()
        snapshot = loadedSnapshot
        watchSessionManager.refreshConnectionState()
        watchSessionManager.send(snapshot: loadedSnapshot)
    }

    func refreshFromUserAction() async {
        isLoading = true
        errorMessage = nil

        do {
            try await refresh()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func applyLiveWorkoutState(_ state: LiveWorkoutState) {
        liveWorkoutState = state
        snapshot.heartRate = state.heartRate ?? snapshot.heartRate
        snapshot.activeEnergy = max(snapshot.activeEnergy, state.activeEnergy)
        snapshot.distance = max(snapshot.distance, state.distance)
        snapshot.lastUpdated = state.updatedAt
    }
}
