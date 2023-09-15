//
//  PlayerNode.swift
//  BlowPlane
//


import SpriteKit

class PlaneNode: Node {
    // Textures
    private var straightTexture: SKTexture!
    private var leftTexture: SKTexture!
    private var rightTexture: SKTexture!
    private var straightTexture_shadow: SKTexture!
    private var leftTexture_shadow: SKTexture!
    private var rightTexture_shadow: SKTexture!
    
    private var _node: SKSpriteNode
    private var shadow: SKSpriteNode
    
    var node: SKNode { _node }
    
    init(height: CGFloat) {
        let size = CGSize(width: height, height: height)
        
        straightTexture = SKTexture(imageNamed: "plane")
        leftTexture = SKTexture(imageNamed: "plane_left")
        rightTexture = SKTexture(imageNamed: "plane_right")
        
        straightTexture_shadow = SKTexture(imageNamed: "plane_shadow")
        leftTexture_shadow = SKTexture(imageNamed: "plane_left_shadow")
        rightTexture_shadow = SKTexture(imageNamed: "plane_right_shadow")
        
        _node = SKSpriteNode(texture: straightTexture, size: size)
        _node.physicsBody = SKPhysicsBody(texture: straightTexture, size: size)
        
        shadow = SKSpriteNode(texture: straightTexture_shadow, size: size)
        shadow.zPosition = -1
        setShadowDistance(-10)
        _node.addChild(shadow)
    }
    
    private func setShadowDistance(_ distance: CGFloat) {
        shadow.position.y = distance
    }
}

extension PlaneNode {
    enum Tilt {
        case left, right, straight
    }
    
    func setTilt(_ tilt: Tilt) {
        switch tilt {
        case .left:
            _node.texture = leftTexture
            shadow.texture = leftTexture_shadow
        case .right:
            _node.texture = rightTexture
            shadow.texture = rightTexture_shadow
        case .straight:
            _node.texture = straightTexture
            shadow.texture = straightTexture_shadow
        }
    }
}

extension PlaneNode {
    func setAltitude(_ altitude: CGFloat) {
        let altitude = min(max(altitude, 0), 1)
        _node.setScale(altitude * 0.3 + 0.7)
        setShadowDistance(-altitude * 50)
    }
}
