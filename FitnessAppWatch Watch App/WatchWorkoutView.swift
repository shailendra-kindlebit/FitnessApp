//
//  WatchWorkoutView.swift
//  FitnessApp
//

#if os(watchOS)

import HealthKit
import SwiftUI

struct WatchWorkoutView: View {
    @State private var workoutManager = WatchWorkoutManager()

    var body: some View {
        NavigationStack {
            ZStack {
                WatchBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        scoreCard
                        metricGrid
                        controlPanel
                        errorBanner
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("Fit Pulse")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(workoutManager.liveState.state.capitalized)
                .font(.system(.caption, design: .rounded, weight: .black))
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.62))

            Text(workoutManager.liveState.elapsedTime.formattedDuration)
                .font(.system(size: 36, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }

    private var scoreCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                HeartRateGauge(heartRate: workoutManager.liveState.heartRate)

                VStack(alignment: .leading, spacing: 5) {
                    Text("Live Heart")
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .foregroundStyle(.white.opacity(0.62))
                    Text(workoutManager.liveState.heartRate.map { "\(Int($0)) bpm" } ?? "-- bpm")
                        .font(.system(.title3, design: .rounded, weight: .black))
                        .foregroundStyle(.white)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Text("Sending to iPhone")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
            }

            GradientProgressBar(value: heartRateProgress, gradient: WatchPalette.heart)
                .frame(height: 9)
        }
        .padding(14)
        .background(WatchPalette.hero, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.24), lineWidth: 1))
    }

    private var metricGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                WatchMetricCard(
                    title: "Move",
                    value: "\(Int(workoutManager.liveState.activeEnergy))",
                    unit: "kcal",
                    systemImage: "flame.fill",
                    gradient: WatchPalette.energy
                )

                WatchMetricCard(
                    title: "Distance",
                    value: String(format: "%.2f", workoutManager.liveState.distance / 1_000),
                    unit: "km",
                    systemImage: "map.fill",
                    gradient: WatchPalette.calm
                )
            }

            WatchMetricCard(
                title: "Sync",
                value: "#\(workoutManager.liveState.sequence)",
                unit: "updates",
                systemImage: "iphone.radiowaves.left.and.right",
                gradient: WatchPalette.steps
            )
        }
    }

    private var controlPanel: some View {
        VStack(spacing: 8) {
            if workoutManager.isWorkoutRunning {
                HStack(spacing: 8) {
                    Button {
                        if workoutManager.liveState.state == "paused" {
                            workoutManager.resumeWorkout()
                        } else {
                            workoutManager.pauseWorkout()
                        }
                    } label: {
                        Image(systemName: workoutManager.liveState.state == "paused" ? "play.fill" : "pause.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WatchControlButtonStyle(gradient: WatchPalette.steps))

                    Button {
                        workoutManager.endWorkout()
                    } label: {
                        Image(systemName: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(WatchControlButtonStyle(gradient: WatchPalette.heart))
                }
            } else {
                Button {
                    Task { await workoutManager.startWorkout(activityType: .running, locationType: .outdoor) }
                } label: {
                    Label("Start Run", systemImage: "figure.run")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(WatchControlButtonStyle(gradient: WatchPalette.energy))
            }
        }
    }

    @ViewBuilder
    private var errorBanner: some View {
        if let errorMessage = workoutManager.errorMessage {
            Text(errorMessage)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.26), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.20), lineWidth: 1))
        }
    }

    private var heartRateProgress: Double {
        min((workoutManager.liveState.heartRate ?? 0) / 180, 1)
    }
}

private struct WatchBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.04, green: 0.07, blue: 0.16),
                Color(red: 0.05, green: 0.30, blue: 0.36),
                Color(red: 0.18, green: 0.20, blue: 0.34)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [Color(red: 0.99, green: 0.47, blue: 0.36).opacity(0.28), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 170
            )
        }
        .ignoresSafeArea()
    }
}

private enum WatchPalette {
    static let hero = LinearGradient(
        colors: [
            Color(red: 0.08, green: 0.22, blue: 0.33),
            Color(red: 0.04, green: 0.58, blue: 0.60),
            Color(red: 0.99, green: 0.47, blue: 0.36)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let energy = LinearGradient(colors: [Color(red: 1.00, green: 0.73, blue: 0.32), Color(red: 0.98, green: 0.38, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let steps = LinearGradient(colors: [Color(red: 0.28, green: 0.86, blue: 0.82), Color(red: 0.14, green: 0.43, blue: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let calm = LinearGradient(colors: [Color(red: 0.60, green: 0.94, blue: 0.74), Color(red: 0.07, green: 0.55, blue: 0.52)], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let heart = LinearGradient(colors: [Color(red: 1.00, green: 0.49, blue: 0.56), Color(red: 0.85, green: 0.19, blue: 0.32)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

private struct HeartRateGauge: View {
    let heartRate: Double?

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.18), lineWidth: 9)
            Circle()
                .trim(from: 0, to: min((heartRate ?? 0) / 180, 1))
                .stroke(WatchPalette.heart, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.7, dampingFraction: 0.82), value: heartRate)

            Image(systemName: "heart.fill")
                .font(.headline.weight(.black))
                .foregroundStyle(.white)
        }
        .frame(width: 72, height: 72)
    }
}

private struct WatchMetricCard: View {
    let title: String
    let value: String
    let unit: String
    let systemImage: String
    let gradient: LinearGradient

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(.caption.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(gradient, in: Circle())

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.62))
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(.headline, design: .rounded, weight: .black))
                        .monospacedDigit()
                    Text(unit)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(.white.opacity(0.56))
                }
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.white.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.22), lineWidth: 1))
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

private struct WatchControlButtonStyle: ButtonStyle {
    let gradient: LinearGradient

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .black))
            .foregroundStyle(.white)
            .padding(.vertical, 12)
            .background(gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).stroke(.white.opacity(0.24), lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.72), value: configuration.isPressed)
    }
}

private extension TimeInterval {
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }

        return String(format: "%02d:%02d", minutes, seconds)
    }
}

#endif
