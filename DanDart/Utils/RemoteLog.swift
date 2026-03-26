//
//  RemoteLog.swift
//  DanDart
//
//  Central logging gate for remote match logs
//  Reduces log spam by gating noisy categories while keeping important flow logs visible
//

import Foundation

enum RemoteLogCategory {
    case realtime
    case flow
    case lobby
    case voice
    case rpc
    case terminal
    
    case render
    case overlay
    case finalThrow
    case bustCheck
    case cardLifecycle
    case fetchMatchVerbose
}

enum RemoteLog {
    static var enabled: Set<RemoteLogCategory> = [
        .realtime,
        .flow,
        .lobby,
        .voice,
        .rpc,
        .terminal
    ]
    
    static func log(_ category: RemoteLogCategory, _ message: @autoclosure () -> String) {
        guard enabled.contains(category) else { return }
        print(message())
    }
}
