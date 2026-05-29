//
//  HealthKitManager.swift
//  FitnessApp
//

import Foundation
import HealthKit

enum HealthKitManagerError: LocalizedError {
    case healthDataUnavailable
    case missingQuantityType(HKQuantityTypeIdentifier)

    var errorDescription: String? {
        switch self {
        case .healthDataUnavailable:
            "Health data is not available on this device."
        case .missingQuantityType(let identifier):
            "Unable to create HealthKit type for \(identifier.rawValue)."
        }
    }
}

final class HealthKitManager {
    private let store = HKHealthStore()

    private var stepType: HKQuantityType { HKQuantityType(.stepCount) }
    private var energyType: HKQuantityType { HKQuantityType(.activeEnergyBurned) }
    private var distanceType: HKQuantityType { HKQuantityType(.distanceWalkingRunning) }
    private var heartRateType: HKQuantityType { HKQuantityType(.heartRate) }

    private var readTypes: Set<HKObjectType> {
        [
            stepType,
            energyType,
            distanceType,
            heartRateType,
            HKObjectType.workoutType()
        ]
    }

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType()]
    }

    var isHealthDataAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }

        try await store.requestAuthorization(toShare: shareTypes, read: readTypes)
    }

    func loadTodaySnapshot() async throws -> FitnessSnapshot {
        let start = Calendar.current.startOfDay(for: Date())
        return try await loadSnapshot(start: start, end: Date())
    }

    func loadSnapshot(start: Date, end: Date) async throws -> FitnessSnapshot {
        guard isHealthDataAvailable else {
            throw HealthKitManagerError.healthDataUnavailable
        }

        async let steps = cumulativeSum(for: stepType, unit: .count(), start: start, end: end)
        async let energy = cumulativeSum(for: energyType, unit: .largeCalorie(), start: start, end: end)
        async let distance = cumulativeSum(for: distanceType, unit: .meter(), start: start, end: end)
        async let heartRate = latestHeartRate(start: start, end: end)
        async let workouts = recentWorkouts(start: start, end: end)

        return try await FitnessSnapshot(
            steps: steps,
            activeEnergy: energy,
            distance: distance,
            heartRate: heartRate,
            workouts: workouts,
            lastUpdated: end
        )
    }

    private func cumulativeSum(for type: HKQuantityType, unit: HKUnit, start: Date, end: Date) async throws -> Double {
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, statistics, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let value = statistics?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private func latestHeartRate(start: Date, end: Date) async throws -> Double? {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: heartRateType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let sample = samples?.first as? HKQuantitySample
                let value = sample?.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
                continuation.resume(returning: value)
            }

            store.execute(query)
        }
    }

    private func recentWorkouts(start: Date, end: Date) async throws -> [WorkoutSummary] {
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let predicate = HKQuery.predicateForSamples(
            withStart: start,
            end: end,
            options: [.strictStartDate, .strictEndDate]
        )

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: 5,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                let energyType = HKQuantityType(.activeEnergyBurned)
                let distanceType = HKQuantityType(.distanceWalkingRunning)

                let workouts = (samples as? [HKWorkout] ?? []).map { workout in
                    let calories = workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .largeCalorie()) ?? 0
                    let distance = workout.statistics(for: distanceType)?.sumQuantity()?.doubleValue(for: .meter()) ?? 0

                    return WorkoutSummary(
                        title: workout.workoutActivityType.displayName,
                        date: workout.startDate,
                        duration: workout.duration,
                        calories: calories,
                        distance: distance
                    )
                }

                continuation.resume(returning: workouts)
            }

            store.execute(query)
        }
    }
}

private extension HKWorkoutActivityType {
    var displayName: String {
        switch self {
        case .running:
            "Run"
        case .walking:
            "Walk"
        case .cycling:
            "Ride"
        case .traditionalStrengthTraining:
            "Strength"
        case .highIntensityIntervalTraining:
            "HIIT"
        case .yoga:
            "Yoga"
        case .swimming:
            "Swim"
        case .hiking:
            "Hike"
        default:
            "Workout"
        }
    }
}
