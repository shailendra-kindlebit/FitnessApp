//
//  FitnessMetric.swift
//  FitnessApp
//

import Foundation

enum FitnessMetricKind {
    case steps
    case activeEnergy
    case distance
    case heartRate
}

struct FitnessMetric: Identifiable, Equatable {
    let id = UUID()
    let kind: FitnessMetricKind
    let title: String
    let value: String
    let unit: String
    let symbolName: String
    let tintName: String
}

struct WorkoutSummary: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let date: Date
    let duration: TimeInterval
    let calories: Double
    let distance: Double
}

struct FitnessSnapshot: Equatable {
    var steps: Double
    var activeEnergy: Double
    var distance: Double
    var heartRate: Double?
    var workouts: [WorkoutSummary]
    var lastUpdated: Date

    static let empty = FitnessSnapshot(
        steps: 0,
        activeEnergy: 0,
        distance: 0,
        heartRate: nil,
        workouts: [],
        lastUpdated: Date()
    )

    var metrics: [FitnessMetric] {
        [
            FitnessMetric(
                kind: .steps,
                title: "Steps",
                value: Self.wholeNumberFormatter.string(from: NSNumber(value: steps)) ?? "0",
                unit: "today",
                symbolName: "figure.walk",
                tintName: "indigo"
            ),
            FitnessMetric(
                kind: .activeEnergy,
                title: "Move",
                value: Self.wholeNumberFormatter.string(from: NSNumber(value: activeEnergy)) ?? "0",
                unit: "kcal",
                symbolName: "flame.fill",
                tintName: "orange"
            ),
            FitnessMetric(
                kind: .distance,
                title: "Distance",
                value: Self.decimalFormatter.string(from: NSNumber(value: distance / 1_000)) ?? "0",
                unit: "km",
                symbolName: "map.fill",
                tintName: "teal"
            ),
            FitnessMetric(
                kind: .heartRate,
                title: "Heart",
                value: heartRate.map { Self.wholeNumberFormatter.string(from: NSNumber(value: $0)) ?? "--" } ?? "--",
                unit: "bpm",
                symbolName: "heart.fill",
                tintName: "pink"
            )
        ]
    }

    var moveProgress: Double {
        min(activeEnergy / 600, 1)
    }

    var stepProgress: Double {
        min(steps / 10_000, 1)
    }

    private static let wholeNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    private static let decimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()
}
