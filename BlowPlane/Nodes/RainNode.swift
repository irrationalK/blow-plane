//
//  RainNode.swift
//  BlowPlane
//


import SpriteKit

class RainNode: Node {
    private var rainemitter: SKEmitterNode!
    private var cloudsemitter: SKEmitterNode!
    
    var isRaining = false {
        didSet {
            guard oldValue != isRaining else { return }
            if isRaining {
                startRain()
            } else {
                stopRain()
            }
        }
    }
    
    var node: SKNode
    
    init() {
        node = SKNode()
        
        rainemitter = SKEmitterNode(fileNamed: "Rain")
        rainemitter.position = CGPoint(x: 0, y: 0)
        rainemitter.particleBirthRate = 0
        node.addChild(rainemitter)
        
        cloudsemitter = SKEmitterNode(fileNamed: "Clouds")
        cloudsemitter.position = CGPoint(x: 0, y: 100)
        cloudsemitter.particleBirthRate = 0
        node.addChild(cloudsemitter)
    }
    
    private func startRain() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            guard self.isRaining else { return } // make sure it is still raining at this point
            self.rainemitter.particleBirthRate = 500
        }
        cloudsemitter.particleBirthRate = 270
    }
    
    private func stopRain() {
        rainemitter.particleBirthRate = 0
        cloudsemitter.particleBirthRate = 0
    }
}
