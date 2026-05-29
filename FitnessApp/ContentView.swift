//
//  ContentView.swift
//  FitnessApp
//

import SwiftUI

struct ContentView: View {
    @State private var viewModel = FitnessDashboardViewModel()
    @State private var selectedMetricKind: FitnessMetricKind = .steps

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        header
                        permissionBanner
                        todaySummary
                        liveWorkoutPanel
                        activityRings
                        metricsSection
                        selectedDetail
                        workoutsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                     Text("Fitness")
                         .foregroundColor(.white) // Title color
                         .font(.headline)
                 }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await viewModel.refreshFromUserAction() }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(RefreshButtonStyle())
                    .disabled(viewModel.isLoading)
                }
            }
            .task {
                guard viewModel.hasRequestedAccess == false else { return }
                await viewModel.requestAccessAndRefresh()
            }
        }
    }

    private var selectedMetric: FitnessMetric {
        viewModel.snapshot.metrics.first { $0.kind == selectedMetricKind } ?? viewModel.snapshot.metrics[0]
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Fit Pulse")
                    .font(.system(.largeTitle, design: .rounded, weight: .black))
                    .foregroundStyle(.white)

                Text(viewModel.snapshot.lastUpdated, format: .dateTime.weekday(.wide).month().day().hour().minute())
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 12)

            WatchStatusBadge(title: viewModel.watchConnectionTitle)
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        if let errorMessage = viewModel.errorMessage {
            MessageBanner(
                title: "Health access needed",
                message: errorMessage,
                systemImage: "heart.text.square.fill",
                tint: .red
            ) {
                Task { await viewModel.requestAccessAndRefresh() }
            }
        } else if !viewModel.canRequestHealthAccess {
            MessageBanner(
                title: "Health unavailable",
                message: "This device cannot provide HealthKit data.",
                systemImage: "exclamationmark.triangle.fill",
                tint: .orange,
                action: nil
            )
        }
    }

    private var todaySummary: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                ScoreGauge(score: dailyScore, status: scoreStatus)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Today Score")
                            .font(.caption.weight(.black))
                            .textCase(.uppercase)
                            .foregroundStyle(.white.opacity(0.68))

                        Spacer()

                        Button {
                            Task { await viewModel.refreshFromUserAction() }
                        } label: {
                            Image(systemName: viewModel.isLoading ? "waveform.path.ecg" : "bolt.heart.fill")
                                .font(.headline.weight(.bold))
                                .frame(width: 42, height: 42)
                        }
                        .buttonStyle(GlassIconButtonStyle())
                        .disabled(viewModel.isLoading)
                    }

                    Text(scoreMessage)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Based on movement, calories, distance, and latest heart-rate availability.")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.66))
                }
            }

            GradientProgressBar(value: Double(dailyScore) / 100, gradient: AppGradient.vital)
                .frame(height: 12)

            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ScoreBreakdownPill(title: "Move", value: "\(Int(moveScore)) pts", systemImage: "flame.fill", gradient: AppGradient.energy)
                    ScoreBreakdownPill(title: "Steps", value: "\(Int(stepScore)) pts", systemImage: "figure.walk", gradient: AppGradient.steps)
                }

                HStack(spacing: 10) {
                    ScoreBreakdownPill(title: "Distance", value: "\(Int(distanceScore)) pts", systemImage: "map.fill", gradient: AppGradient.calm)
                    ScoreBreakdownPill(title: "Heart", value: "\(Int(heartScore)) pts", systemImage: "heart.fill", gradient: AppGradient.heart)
                }
            }
        }
        .padding(20)
        .background(AppGradient.hero, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
        .shadow(color: .black.opacity(0.22), radius: 24, x: 0, y: 16)
    }

    @ViewBuilder
    private var liveWorkoutPanel: some View {
        if let liveWorkoutState = viewModel.liveWorkoutState {
            LiveWorkoutCard(state: liveWorkoutState)
        }
    }

    private var activityRings: some View {
        HStack(spacing: 14) {
            ActivityRingCard(
                title: "Move",
                value: viewModel.snapshot.moveProgress,
                centerText: "\(Int(viewModel.snapshot.activeEnergy))",
                caption: "600 kcal",
                systemImage: "flame.fill",
                gradient: AppGradient.energy
            ) {
                selectedMetricKind = .activeEnergy
            }

            ActivityRingCard(
                title: "Steps",
                value: viewModel.snapshot.stepProgress,
                centerText: "\(Int(viewModel.snapshot.steps))",
                caption: "10k goal",
                systemImage: "figure.walk",
                gradient: AppGradient.steps
            ) {
                selectedMetricKind = .steps
            }
        }
    }

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Health Metrics")

            VStack(spacing: 10) {
                ForEach(viewModel.snapshot.metrics) { metric in
                    MetricRow(metric: metric, isSelected: metric.kind == selectedMetricKind) {
                        selectedMetricKind = metric.kind
                    }
                }
            }
        }
    }

    private var selectedDetail: some View {
        DetailCard(
            metric: selectedMetric,
            progress: progressValue(for: selectedMetricKind),
            goalText: goalText(for: selectedMetricKind),
            detailText: detailText(for: selectedMetricKind),
            gradient: gradient(for: selectedMetric)
        )
    }

    private var workoutsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Recent Workouts", trailing: "\(viewModel.snapshot.workouts.count)")

            if viewModel.snapshot.workouts.isEmpty {
                EmptyWorkoutCard()
            } else {
                VStack(spacing: 10) {
                    ForEach(viewModel.snapshot.workouts) { workout in
                        WorkoutRow(workout: workout)
                    }
                }
            }
        }
    }

    private var dailyScore: Int {
        min(Int((moveScore + stepScore + distanceScore + heartScore).rounded()), 100)
    }

    private var moveScore: Double {
        viewModel.snapshot.moveProgress * 35
    }

    private var stepScore: Double {
        viewModel.snapshot.stepProgress * 35
    }

    private var distanceScore: Double {
        min(viewModel.snapshot.distance / 5_000, 1) * 20
    }

    private var heartScore: Double {
        guard let heartRate = viewModel.snapshot.heartRate else { return 0 }
        return (45...165).contains(Int(heartRate)) ? 10 : 5
    }

    private var scoreStatus: String {
        switch dailyScore {
        case 80...100:
            "Strong"
        case 55..<80:
            "On Track"
        case 25..<55:
            "Keep Moving"
        default:
            "Getting Started"
        }
    }

    private var scoreMessage: String {
        switch dailyScore {
        case 80...100:
            "Great activity balance today."
        case 55..<80:
            "You are building solid momentum."
        case 25..<55:
            "A short walk can lift your score."
        default:
            "Start with steps or a quick workout."
        }
    }

    private func progressValue(for kind: FitnessMetricKind) -> Double {
        switch kind {
        case .steps:
            viewModel.snapshot.stepProgress
        case .activeEnergy:
            viewModel.snapshot.moveProgress
        case .distance:
            min(viewModel.snapshot.distance / 5_000, 1)
        case .heartRate:
            min((viewModel.snapshot.heartRate ?? 0) / 180, 1)
        }
    }

    private func goalText(for kind: FitnessMetricKind) -> String {
        switch kind {
        case .steps:
            "10,000 steps"
        case .activeEnergy:
            "600 kcal"
        case .distance:
            "5.0 km"
        case .heartRate:
            "Latest sample"
        }
    }

    private func detailText(for kind: FitnessMetricKind) -> String {
        switch kind {
        case .steps:
            "Daily step progress from HealthKit. Refresh after walking or workouts to pull the latest Apple Watch data."
        case .activeEnergy:
            "Active energy tracks movement calories, separate from resting calories. Apple Watch usually records this automatically."
        case .distance:
            "Walking and running distance recorded today. Outdoor workouts and phone motion can both contribute."
        case .heartRate:
            "Shows the latest heart-rate sample available to the app. Health permissions control what is visible."
        }
    }

    private func gradient(for metric: FitnessMetric) -> LinearGradient {
        switch metric.tintName {
        case "orange": AppGradient.energy
        case "teal": AppGradient.calm
        case "pink": AppGradient.heart
        default: AppGradient.steps
        }
    }
}

private struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.16),
                Color(red: 0.06, green: 0.15, blue: 0.28),
                Color(red: 0.05, green: 0.36, blue: 0.42),
                Color(red: 0.18, green: 0.20, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [Color(red: 0.99, green: 0.47, blue: 0.36).opacity(0.32), .clear],
                center: .topTrailing,
                startRadius: 80,
                endRadius: 420
            )
        }
        .overlay {
            LinearGradient(colors: [.black.opacity(0.06), .clear, .black.opacity(0.30)], startPoint: .top, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }
}

private enum AppGradient {
    static let hero = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.22, blue: 0.33),
            Color(red: 0.04, green: 0.58, blue: 0.60),
            Color(red: 0.99, green: 0.47, blue: 0.36)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let vital = LinearGradient(
        colors: [
            Color(red: 0.77, green: 0.97, blue: 0.92),
            Color(red: 0.19, green: 0.82, blue: 0.78),
            Color(red: 1.00, green: 0.65, blue: 0.40)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    static let energy = LinearGradient(colors: [Color(red: 1.00, green: 0.73, blue: 0.32), Color(red: 0.98, green: 0.38, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let steps = LinearGradient(colors: [Color(red: 0.28, green: 0.86, blue: 0.82), Color(red: 0.14, green: 0.43, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let calm = LinearGradient(colors: [Color(red: 0.60, green: 0.94, blue: 0.74), Color(red: 0.07, green: 0.55, blue: 0.52)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let heart = LinearGradient(colors: [Color(red: 1.00, green: 0.49, blue: 0.56), Color(red: 0.85, green: 0.19, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct WatchStatusBadge: View {
    let title: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "applewatch")
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .font(.caption.weight(.black))
        .foregroundStyle(.white)
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.white.opacity(0.18), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.24), lineWidth: 1))
    }
}

private struct ScoreGauge: View {
    let score: Int
    let status: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 12)

            Circle()
                .trim(from: 0, to: Double(score) / 100)
                .stroke(AppGradient.vital, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.82), value: score)

            VStack(spacing: 2) {
                Text("\(score)")
                    .font(.system(.title, design: .rounded, weight: .black))
                    .monospacedDigit()
                Text(status)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundStyle(.white)
        }
        .frame(width: 112, height: 112)
    }
}

private struct ScoreBreakdownPill: View {
    let title: String
    let value: String
    let systemImage: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                Text(value)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct SummaryPill: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.16), in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                Text(value)
                    .font(.caption.weight(.black))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.13), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ActivityRingCard: View {
    let title: String
    let value: Double
    let centerText: String
    let caption: String
    let systemImage: String
    let gradient: LinearGradient
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: systemImage)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 34, height: 34)
                        .background(gradient, in: Circle())
                    Spacer()
                    Text(title)
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                        .foregroundStyle(.white.opacity(0.78))
                }

                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.20), lineWidth: 13)
                    Circle()
                        .trim(from: 0, to: value)
                        .stroke(gradient, style: StrokeStyle(lineWidth: 13, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.7, dampingFraction: 0.82), value: value)

                    VStack(spacing: 2) {
                        Text(centerText)
                            .font(.system(.title3, design: .rounded, weight: .black))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.52)
                        Text(caption)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.64))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.white)
                    .padding(16)
                }
                .frame(height: 132)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct SectionHeader: View {
    let title: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(title)
                .font(.system(.title3, design: .rounded, weight: .black))
                .foregroundStyle(.white)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption.weight(.black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.18), in: Capsule())
            }
        }
    }
}

private struct MetricRow: View {
    let metric: FitnessMetric
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: metric.symbolName)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(gradient, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .foregroundStyle(.white)
                    Text(goalSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(metric.value)
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .monospacedDigit()
                    Text(metric.unit)
                        .font(.caption.weight(.black))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .foregroundStyle(.white)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "chevron.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white.opacity(isSelected ? 1 : 0.52))
            }
            .padding(14)
            .background(.white.opacity(isSelected ? 0.24 : 0.17), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(isSelected ? 0.52 : 0.26), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }

    private var goalSubtitle: String {
        switch metric.kind {
        case .steps:
            "Daily movement"
        case .activeEnergy:
            "Move calories"
        case .distance:
            "Walk + run"
        case .heartRate:
            "Latest reading"
        }
    }

    private var gradient: LinearGradient {
        switch metric.tintName {
        case "orange": AppGradient.energy
        case "teal": AppGradient.calm
        case "pink": AppGradient.heart
        default: AppGradient.steps
        }
    }
}

private struct LiveWorkoutCard: View {
    let state: LiveWorkoutState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "applewatch.radiowaves.left.and.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .background(AppGradient.heart, in: Circle())

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Live Watch Workout")
                            .font(.system(.headline, design: .rounded, weight: .black))
                            .foregroundStyle(.white)
                        Text(state.state.capitalized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white.opacity(0.64))
                    }
                }

                Spacer()

                Text(state.elapsedTime.formattedDuration)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }

            HStack(spacing: 10) {
                LiveWorkoutMetric(title: "Heart", value: state.heartRate.map { "\(Int($0))" } ?? "--", unit: "bpm", systemImage: "heart.fill", gradient: AppGradient.heart)
                LiveWorkoutMetric(title: "Move", value: "\(Int(state.activeEnergy))", unit: "kcal", systemImage: "flame.fill", gradient: AppGradient.energy)
                LiveWorkoutMetric(title: "Distance", value: String(format: "%.2f", state.distance / 1_000), unit: "km", systemImage: "map.fill", gradient: AppGradient.calm)
            }
        }
        .padding(16)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
    }
}

private struct LiveWorkoutMetric: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                Text(value)
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(unit)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(.white.opacity(0.58))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct DetailCard: View {
    let metric: FitnessMetric
    let progress: Double
    let goalText: String
    let detailText: String
    let gradient: LinearGradient

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: metric.symbolName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(gradient, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Detail")
                        .font(.caption.weight(.black))
                        .textCase(.uppercase)
                        .foregroundStyle(.white.opacity(0.62))
                    Text(metric.title)
                        .font(.system(.title2, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                }

                Spacer()
            }

            GradientProgressBar(value: progress, gradient: gradient)
                .frame(height: 12)

            HStack(spacing: 8) {
                DetailChip(title: goalText, systemImage: "target")
                DetailChip(title: "\(Int((progress * 100).rounded()))%", systemImage: "chart.line.uptrend.xyaxis")
            }

            Text(detailText)
                .font(.callout.weight(.medium))
                .foregroundStyle(.white.opacity(0.76))
        }
        .padding(18)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
    }
}

private struct DetailChip: View {
    let title: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .font(.caption.weight(.bold))
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.14), in: Capsule())
    }
}

private struct WorkoutRow: View {
    let workout: WorkoutSummary

    var body: some View {
        Button {} label: {
            HStack(spacing: 12) {
                Image(systemName: "figure.run.circle.fill")
                    .font(.title)
                    .foregroundStyle(AppGradient.calm)
                    .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workout.title)
                        .font(.system(.headline, design: .rounded, weight: .bold))
                    Text(workout.date, format: .dateTime.month().day().hour().minute())
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .foregroundStyle(.white)

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(workout.duration.formattedDuration)
                        .font(.system(.subheadline, design: .rounded, weight: .black))
                    Text("\(Int(workout.calories)) kcal")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .foregroundStyle(.white)
            }
            .padding(14)
            .background(.white.opacity(0.17), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.26), lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct EmptyWorkoutCard: View {
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "figure.run")
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(AppGradient.calm, in: Circle())

            VStack(alignment: .leading, spacing: 5) {
                Text("No workouts yet")
                    .font(.system(.headline, design: .rounded, weight: .black))
                    .foregroundStyle(.white)
                Text("Start a workout on Apple Watch and refresh to see it here.")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.white.opacity(0.70))
            }

            Spacer()
        }
        .padding(16)
        .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.28), lineWidth: 1))
    }
}

private struct MessageBanner: View {
    let title: String
    let message: String
    let systemImage: String
    let tint: Color
    let action: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if let action {
                Button(action: action) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.borderedProminent)
                .tint(tint)
                .accessibilityLabel("Retry")
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(tint.opacity(0.24), lineWidth: 1))
    }
}

private struct GradientProgressBar: View {
    let value: Double
    let gradient: LinearGradient

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.18))
                Capsule()
                    .fill(gradient)
                    .frame(width: max(proxy.size.width * min(max(value, 0), 1), 8))
                    .animation(.spring(response: 0.65, dampingFraction: 0.82), value: value)
            }
        }
    }
}

private struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? 0.05 : 0)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct GlassIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(.white.opacity(configuration.isPressed ? 0.24 : 0.16), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.28), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private struct RefreshButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .labelStyle(.iconOnly)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(width: 38, height: 38)
            .background(AppGradient.heart, in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.35), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        let minutes = Int(self / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(remainingMinutes)m"
    }
}

#Preview {
    ContentView()
}
