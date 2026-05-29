//
//  WorkoutSyncModels.swift
//  FitnessApp
//

import Foundation

enum WorkoutSyncKey {
    static let messageType = "messageType"
    static let liveWorkout = "liveWorkout"
    static let heartRate = "heartRate"
    static let activeEnergy = "activeEnergy"
    static let distance = "distance"
    static let elapsedTime = "elapsedTime"
    static let state = "state"
    static let startedAt = "startedAt"
    static let updatedAt = "updatedAt"
    static let sequence = "sequence"
}

struct LiveWorkoutState: Equatable {
    var heartRate: Double?
    var activeEnergy: Double
    var distance: Double
    var elapsedTime: TimeInterval
    var state: String
    var startedAt: Date
    var updatedAt: Date
    var sequence: Int

    init(
        heartRate: Double? = nil,
        activeEnergy: Double = 0,
        distance: Double = 0,
        elapsedTime: TimeInterval = 0,
        state: String = "notStarted",
        startedAt: Date = Date(),
        updatedAt: Date = Date(),
        sequence: Int = 0
    ) {
        self.heartRate = heartRate
        self.activeEnergy = activeEnergy
        self.distance = distance
        self.elapsedTime = elapsedTime
        self.state = state
        self.startedAt = startedAt
        self.updatedAt = updatedAt
        self.sequence = sequence
    }

    init?(dictionary: [String: Any]) {
        guard dictionary[WorkoutSyncKey.messageType] as? String == WorkoutSyncKey.liveWorkout else {
            return nil
        }

        let heartRate = dictionary[WorkoutSyncKey.heartRate] as? Double
        let activeEnergy = dictionary[WorkoutSyncKey.activeEnergy] as? Double ?? 0
        let distance = dictionary[WorkoutSyncKey.distance] as? Double ?? 0
        let elapsedTime = dictionary[WorkoutSyncKey.elapsedTime] as? TimeInterval ?? 0
        let state = dictionary[WorkoutSyncKey.state] as? String ?? "unknown"
        let startedAtInterval = dictionary[WorkoutSyncKey.startedAt] as? TimeInterval ?? Date().timeIntervalSince1970
        let updatedAtInterval = dictionary[WorkoutSyncKey.updatedAt] as? TimeInterval ?? Date().timeIntervalSince1970
        let sequence = dictionary[WorkoutSyncKey.sequence] as? Int ?? 0

        self.init(
            heartRate: heartRate,
            activeEnergy: activeEnergy,
            distance: distance,
            elapsedTime: elapsedTime,
            state: state,
            startedAt: Date(timeIntervalSince1970: startedAtInterval),
            updatedAt: Date(timeIntervalSince1970: updatedAtInterval),
            sequence: sequence
        )
    }

    var dictionary: [String: Any] {
        var payload: [String: Any] = [
            WorkoutSyncKey.messageType: WorkoutSyncKey.liveWorkout,
            WorkoutSyncKey.activeEnergy: activeEnergy,
            WorkoutSyncKey.distance: distance,
            WorkoutSyncKey.elapsedTime: elapsedTime,
            WorkoutSyncKey.state: state,
            WorkoutSyncKey.startedAt: startedAt.timeIntervalSince1970,
            WorkoutSyncKey.updatedAt: updatedAt.timeIntervalSince1970,
            WorkoutSyncKey.sequence: sequence
        ]

        if let heartRate {
            payload[WorkoutSyncKey.heartRate] = heartRate
        }

        return payload
    }
}
