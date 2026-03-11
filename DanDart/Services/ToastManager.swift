//
//  ToastManager.swift
//  DanDart
//
//  Manages toast notification state and auto-dismiss logic
//

import SwiftUI

class ToastManager: ObservableObject {
    static let shared = ToastManager()
    
    @Published var currentToast: ToastMessage?
    @Published var isVisible: Bool = false
    
    private var dismissTask: Task<Void, Never>?
    
    private init() {}
    
    struct ToastMessage: Identifiable {
        let id = UUID()
        let symbolName: String
        let message: String
    }
    
    func show(symbolName: String, message: String, duration: TimeInterval = 2.5) {
        dismissTask?.cancel()
        
        currentToast = ToastMessage(symbolName: symbolName, message: message)
        
        withAnimation {
            isVisible = true
        }
        
        dismissTask = Task {
            try? await Task.sleep(for: .seconds(duration))
            
            guard !Task.isCancelled else { return }
            
            await MainActor.run {
                withAnimation {
                    isVisible = false
                }
                
                Task {
                    try? await Task.sleep(for: .seconds(0.3))
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        currentToast = nil
                    }
                }
            }
        }
    }
    
    func dismiss() {
        dismissTask?.cancel()
        
        withAnimation {
            isVisible = false
        }
        
        Task {
            try? await Task.sleep(for: .seconds(0.3))
            await MainActor.run {
                currentToast = nil
            }
        }
    }
}
