//
//  RainStateMachine.swift
//  BlowPlane
//


import Foundation

class RainStateMachine {
    private var elapsedTime: TimeInterval = 0
    private var nextRainDuration: TimeInterval = 0
    private var nextRainTime: TimeInterval = 0
    
    /// used to determine if there should be rain; call update(deltaTime:) first
    private(set) var isRaining = false
    
    init() {
        calculateNextRainTime()
    }
    
    private func calculateNextRainTime() {
        nextRainTime = elapsedTime + nextRainDuration + TimeInterval.random(in: 8...16)
        nextRainDuration = TimeInterval.random(in: 6...10)
    }
    
    /// should be called in the game update loop
    func update(deltaTime: TimeInterval) {
        elapsedTime += deltaTime
        
        isRaining = elapsedTime >= nextRainTime && elapsedTime <= nextRainTime + nextRainDuration
        
        if elapsedTime > nextRainTime + nextRainDuration {
            calculateNextRainTime()
        }
    }
}
