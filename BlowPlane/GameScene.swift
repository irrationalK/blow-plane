//
//  GameScene.swift
//  BlowPlane
//


import SpriteKit
import CoreMotion

class GameScene: SKScene {
    // MARK: constants
    private static let playerTiltSpeed: CGFloat = 25
    private static let maxPlayerSpeed: CGFloat = 8
    private static let maxRainingPlayerSpeed: CGFloat = 5
    private static let playerSpeedAcceleration: CGFloat = 0.3
    private static let playerSpeedSlowDeceleration: CGFloat = 0.015
    private static let playerSpeedDeceleration: CGFloat = 0.03
    private static let playerCrashingSpeedDeceleration: CGFloat = 0.5
    
    // MARK: nodes
    private var backgroundTop: SKSpriteNode!
    private var backgroundBottom: SKSpriteNode!
    private var player: PlaneNode!
    private var rain: RainNode!
    private var scoreNode: SKLabelNode!
    private var splashscreen: SKSpriteNode!
    
    private var obstacles: [SKSpriteNode]!
    
    // MARK: sensors
    private var microphone: Microphone!
    private var motionManager: CMMotionManager!
    
    // MARK: state
    private var gameState: GameState = .prepared
    private var isCrashing = false // true if the player had a collision, in this case the plane cannot accelerate anymore
    private var rainStateMachine: RainStateMachine!
    
    private var playerSpeed: CGFloat = 0 // important variable
    private var timeLeftWithSlowDeceleration: TimeInterval = 0
    private var score: CGFloat = 0 {
        didSet {
            scoreNode.text = "Score: \(String(format: "%.0f", Double(score)))"
        }
    }
    
    private var lastUpdateTime: TimeInterval = 0
    
    // entry point, initialize all nodes/textures and prepare the game
    override func didMove(to view: SKView) {
        self.physicsWorld.contactDelegate = self
        
        microphone = Microphone()
        microphone.startRecording()
        
        motionManager = CMMotionManager()
        motionManager.startAccelerometerUpdates()
        
        // create nodes
        createPlayer()
        createBackground()
        createObstacles()
        createScore()
        createSplashScreen()
        createRainEmitter()
        
        prepareGame()
    }
    
    /// constants for physics body contact test
    enum PhysicsBodyCategory: UInt32 {
        case player = 1
        case obstacle = 2
    }
    
    override func update(_ currentTime: TimeInterval) {
        // Calculate time since last update
        if (self.lastUpdateTime == 0) {
            self.lastUpdateTime = currentTime
        }
        let dt = currentTime - self.lastUpdateTime
        self.lastUpdateTime = currentTime
        
        // update all objects
        updateRain(deltaTime: dt) // note: rain can appear at any time, even when the game is not started, this is intended
        updatePlayer(deltaTime: dt)
        updateBackground(deltaTime: dt)
        updateScore(deltaTime: dt)
        
        // update the game state
        if gameState == .prepared && playerSpeed > 0 {
            startGame(currentTime: currentTime)
        }
        if gameState == .started && playerSpeed <= 0 {
            gameOver()
        }
    }
}

// MARK: object updates
extension GameScene {
    private func updatePlayer(deltaTime: TimeInterval) {
        updatePlayerTiltPosition(deltaTime: deltaTime)
        updatePlayerSpeed(deltaTime: deltaTime)
        player.setAltitude(playerSpeed / Self.maxPlayerSpeed)
    }
    
    private func updatePlayerSpeed(deltaTime: TimeInterval) {
        let micPower = Double(microphone.normalizedPower)
        var deltaSpeed: CGFloat
        
        if !isCrashing {
            if micPower > 0 {
                timeLeftWithSlowDeceleration = 1.5 // when micPower drops below 0, the plane will first decelerate slowly with playerSpeedSlowDeceleration and then faster with playerSpeedDeceleration
                deltaSpeed = Self.playerSpeedAcceleration * CGFloat(micPower * 60 * deltaTime)
                if rainStateMachine.isRaining {
                    if playerSpeed >= Self.maxRainingPlayerSpeed {
                        deltaSpeed = ((playerSpeed - Self.maxRainingPlayerSpeed) / 20) * CGFloat(60 * deltaTime)
                    }
                }
            } else {
                timeLeftWithSlowDeceleration -= deltaTime
                if rainStateMachine.isRaining {
                    timeLeftWithSlowDeceleration = 0
                }
                if timeLeftWithSlowDeceleration <= 0 {
                    deltaSpeed = Self.playerSpeedDeceleration * CGFloat(-1 * 60 * deltaTime)
                } else {
                    deltaSpeed = Self.playerSpeedSlowDeceleration * CGFloat(-1 * 60 * deltaTime)
                }
                if rainStateMachine.isRaining {
                    deltaSpeed *= 1.5
                }
            }
        } else {
            // the plane had a collision, ignore the microphone and just get slower
            deltaSpeed = Self.playerCrashingSpeedDeceleration * CGFloat(-1 * 60 * deltaTime)
        }
        
        playerSpeed = max(min(playerSpeed + deltaSpeed, Self.maxPlayerSpeed), 0)
    }
    
    /// updates the horizontal position of the player based on the elapsed time and the accelerometer data
    private func updatePlayerTiltPosition(deltaTime: TimeInterval) {
        guard playerSpeed > 0 else {
            // do not allow tilting when plane has landed
            player.setTilt(.right)
            return
        }
        
        guard let xAcceleration = motionManager.accelerometerData?.acceleration.x else { return }
        guard abs(xAcceleration) > 0.01 else {
            // very small value, act like there is no tilt at all!
            player.setTilt(.straight)
            return
        }
        
        // compute the new player position
        let deltaPosition = Self.playerTiltSpeed * CGFloat(xAcceleration * 60 * deltaTime) // 60 and deltaTime should cancel each other out
        let maxXPos = (frame.width / 2) - (player.node.frame.width / 2)
        let minXPos = -maxXPos
        player.node.position.x = min(max(player.node.position.x + deltaPosition, minXPos), maxXPos)
        
        // only tilt the player *texture* if the acceleration is high enough
        let textureChangeThreshold = 0.1
        if xAcceleration > textureChangeThreshold {
            player.setTilt(.right)
        } else if xAcceleration < -textureChangeThreshold {
            player.setTilt(.left)
        } else {
            player.setTilt(.straight)
        }
    }
    
    private func updateBackground(deltaTime: TimeInterval) {
        scrollBackground(by: playerSpeed * CGFloat(60 * deltaTime))
    }
    
    private func updateScore(deltaTime: TimeInterval){
        score += playerSpeed * 0.1 * CGFloat(60 * deltaTime)
    }
    
    private func updateRain(deltaTime: TimeInterval) {
        rainStateMachine.update(deltaTime: deltaTime)
        rain.isRaining = rainStateMachine.isRaining
    }
}

// MARK: game state
extension GameScene {
    /// prepared -> started -> gameOver (and repeat)
    private enum GameState {
        case prepared, started, gameOver
    }
    
    private func prepareGame() {
        addChild(splashscreen)
        splashscreen.run(.fadeIn(withDuration: 0.2))
        isCrashing = false
        gameState = .prepared
    }
    
    private func startGame(currentTime: TimeInterval) {
        score = 0
        splashscreen.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        scoreNode.run(.sequence([.scale(to: 1, duration: 0.2), .move(to: CGPoint(x: 0 , y: size.height - 50 - 44), duration: 0.2)]))
        gameState = .started
    }
    
    private func gameOver() {
        gameState = .gameOver
        scoreNode.run(.sequence([.moveTo(y: size.height * 0.75, duration: 0.2), .scale(to: 1.5, duration: 0.2)])) {
            // after the animation finishes, prepare a new game
            self.prepareGame()
        }
    }
}

// MARK: background
extension GameScene {
    private func scrollBackground(by distance: CGFloat) {
        backgroundTop.position.y -= distance
        backgroundBottom.position.y -= distance
        
        if backgroundBottom.position.y + (backgroundBottom.size.height / 2) < 0 {
            backgroundBottom.position.y = backgroundTop.position.y + backgroundTop.size.height
            let _backgroundBottom = backgroundBottom
            backgroundBottom = backgroundTop
            backgroundTop = _backgroundBottom
            
            // remove / add the obstacles
            backgroundTop.removeAllChildren()
            if let obstacle = nextObstacle() {
                backgroundTop.addChild(obstacle)
            }
        }
    }
    
    /// attaches an obstacle at a random position to the background node
    private func nextObstacle() -> SKNode? {
        guard let obstacle = obstacles.filter({ $0.parent == nil }).randomElement() else { return nil }
        let left = -size.width/2 + obstacle.size.width/2
        let right = -left
        obstacle.zRotation = 0
        obstacle.position = CGPoint(x: CGFloat.random(in: left...right), y: 200)
        return obstacle
    }
}

// MARK: node creation
extension GameScene {
    private func createPlayer() {
        player = PlaneNode(height: 100)
        player.node.position = CGPoint(x: 0, y: player.node.frame.height / 2 + 50)
        player.node.physicsBody?.allowsRotation = false
        player.node.physicsBody?.categoryBitMask = PhysicsBodyCategory.player.rawValue
        player.node.physicsBody?.collisionBitMask = 0 // we handle collisions with the contact test
        player.node.physicsBody?.contactTestBitMask = PhysicsBodyCategory.obstacle.rawValue
        player.node.physicsBody?.isDynamic = false
        addChild(player.node)
    }
    
    private func createRainEmitter() {
        rainStateMachine = RainStateMachine()
        rain = RainNode()
        rain.node.position = CGPoint(x: 0, y: size.height)
        addChild(rain.node)
    }
    
    private func createSplashScreen(){
        splashscreen = SKSpriteNode(imageNamed: "SplashScreen")
        splashscreen.size = CGSize(width: 300, height: 200)
        splashscreen.position = CGPoint(x: 0, y: self.size.height/2)
        splashscreen.zPosition = 2
        splashscreen.run(.repeatForever(.sequence([.scale(to: 0.5, duration: 1.0), .scale(to: 1, duration: 1.0)])))
    }
    
    private func createScore() {
        scoreNode = SKLabelNode(fontNamed: "BadaBoom BB")
        scoreNode.fontSize = CGFloat(36)
        scoreNode.zPosition = 10
        scoreNode.position = CGPoint(x: 0 , y: size.height - 50 - 44) // 44 hardcoded for notch
        scoreNode.color = SKColor.white
        scoreNode.text = "0"
        addChild(scoreNode)
    }
    
    private func createBackground() {
        backgroundBottom = SKSpriteNode(imageNamed: "background")
        // backgroundBottom.scale(to: frame.size)
        backgroundBottom.size = CGSize(width:frame.size.width, height:frame.size.height)
        backgroundBottom.position.y += frame.size.height / 2
        backgroundBottom.zPosition = -10
        addChild(backgroundBottom)
        
        backgroundTop = SKSpriteNode(imageNamed: "background")
        //backgroundTop.scale(to: frame.size)
        backgroundTop.size = CGSize(width:frame.size.width, height:frame.size.height)
        
        backgroundTop.position.y = backgroundBottom.size.height + (backgroundTop.size.height / 2)
        backgroundTop.zPosition = -10
        
        addChild(backgroundTop)
    }
    
    private func createObstacles() {
        obstacles = (1...4).map {
            let texture = SKTexture(imageNamed: "Book\($0)")
            let obstacle = SKSpriteNode(texture: texture)
            obstacle.setScale(0.17)
            obstacle.zPosition = 1
            obstacle.physicsBody = SKPhysicsBody(texture: texture, size: obstacle.frame.size)
            obstacle.physicsBody?.categoryBitMask = PhysicsBodyCategory.obstacle.rawValue
            return obstacle
        }
    }
}

// MARK: SKPhysicsContactDelegate
extension GameScene: SKPhysicsContactDelegate {
    func didBegin(_ contact: SKPhysicsContact) {
        guard gameState == .started else { return }
        // use if instead of guard because in future there could be other collision types
        if contact.bodyA.node == player.node {
            if contact.bodyB.categoryBitMask & PhysicsBodyCategory.obstacle.rawValue != 0 {
                // the player has contact with an obstacle
                
                let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.2)
                let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.2)
                let blink = SKAction.repeat(SKAction.sequence([fadeOut,fadeIn]), count: 3)
                contact.bodyB.node?.run(SKAction.sequence([blink, .removeFromParent()]))
                
                isCrashing = true // forces the plane to loose speed until it stops; after the the gameState will be switched to .gameOver
            }
        }
    }
}
