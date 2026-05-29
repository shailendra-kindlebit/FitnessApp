//
//  WatchSessionManager.swift
//  FitnessApp
//

import Foundation
import WatchConnectivity

enum WatchConnectionState: Equatable {
    case unavailable
    case inactive
    case connected
    case watchAppMissing

    var title: String {
        switch self {
        case .unavailable:
            "Unavailable"
        case .inactive:
            "Inactive"
        case .connected:
            "Connected"
        case .watchAppMissing:
            "Watch app needed"
        }
    }
}

final class WatchSessionManager: NSObject, WCSessionDelegate {
    private let session: WCSession?
    private(set) var connectionState: WatchConnectionState = .unavailable
    private(set) var latestLiveWorkoutState: LiveWorkoutState?

    var onLiveWorkoutUpdate: ((LiveWorkoutState) -> Void)?
    var onConnectionStateChange: ((WatchConnectionState) -> Void)?

    override init() {
        if WCSession.isSupported() {
            session = .default
        } else {
            session = nil
        }

        super.init()
        activate()
    }

    func activate() {
        guard let session else {
            updateConnectionState(.unavailable)
            return
        }

        session.delegate = self
        session.activate()
        refreshConnectionState()
    }

    func send(snapshot: FitnessSnapshot) {
        guard let session, session.activationState == .activated else {
            return
        }

        let context: [String: Any] = [
            "steps": snapshot.steps,
            "activeEnergy": snapshot.activeEnergy,
            "distance": snapshot.distance,
            "heartRate": snapshot.heartRate as Any,
            "updatedAt": snapshot.lastUpdated.timeIntervalSince1970
        ]

        guard shouldSendToWatch(session) else {
            return
        }

        try? session.updateApplicationContext(context)
    }

    func send(workoutState: LiveWorkoutState) {
        guard let session, session.activationState == .activated else {
            return
        }

        let payload = workoutState.dictionary

        if session.isReachable {
            session.sendMessage(payload, replyHandler: nil) { [weak self] _ in
                self?.queueLiveWorkoutPayload(payload, using: session)
            }
        } else {
            queueLiveWorkoutPayload(payload, using: session)
        }
    }

    func refreshConnectionState() {
        guard let session else {
            updateConnectionState(.unavailable)
            return
        }

        #if os(iOS)
        if session.activationState != .activated {
            updateConnectionState(.inactive)
        } else if !session.isPaired || !session.isWatchAppInstalled {
            updateConnectionState(.watchAppMissing)
        } else {
            updateConnectionState(.connected)
        }
        #else
        updateConnectionState(session.activationState == .activated ? .connected : .inactive)
        #endif
    }

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshConnectionState()
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.refreshConnectionState()
        }
    }

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()

        DispatchQueue.main.async { [weak self] in
            self?.refreshConnectionState()
        }
    }
    #endif

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        handleIncomingPayload(applicationContext)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        handleIncomingPayload(userInfo)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        handleIncomingPayload(message)
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        handleIncomingPayload(message)
        replyHandler(["receivedAt": Date().timeIntervalSince1970])
    }

    private func shouldSendToWatch(_ session: WCSession) -> Bool {
        #if os(iOS)
        session.isPaired && session.isWatchAppInstalled
        #else
        true
        #endif
    }

    private func queueLiveWorkoutPayload(_ payload: [String: Any], using session: WCSession) {
        session.transferUserInfo(payload)
        try? session.updateApplicationContext(payload)
    }

    private func handleIncomingPayload(_ payload: [String: Any]) {
        guard let state = LiveWorkoutState(dictionary: payload) else {
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.latestLiveWorkoutState = state
            self?.onLiveWorkoutUpdate?(state)
        }
    }

    private func updateConnectionState(_ state: WatchConnectionState) {
        connectionState = state
        onConnectionStateChange?(state)
    }
}
