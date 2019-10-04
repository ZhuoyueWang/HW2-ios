import UIKit
import ARKit
import SceneKit

class ViewController: UIViewController, ARSCNViewDelegate {
    
    // UI
    @IBOutlet weak var planeSearchLabel: UILabel!
    @IBOutlet weak var planeSearchOverlay: UIView!
    @IBOutlet weak var gameStateLabel: UILabel!
    @IBAction func didTapStartOver(_ sender: Any) { reset() }
    @IBOutlet weak var sceneView: ARSCNView!
    
    private func putPlane() {
        DispatchQueue.main.async {
        self.planeSearchOverlay.isHidden = (self.currentPlane != nil)
        if self.planeCount != 0 {
            self.planeSearchLabel.text = "Tap to place a board"
        } else {
            self.planeSearchLabel.text = "Trying to search a plane"
        }
        }
    }
    
    var playerType = [
        GamePlayer.x: GamePlayerType.human,
        GamePlayer.o: GamePlayerType.ai
    ]
    var planeCount = 0 {
        didSet {
            putPlane()
        }
    }
    var currentPlane:SCNNode? {
        didSet {
            putPlane()
            newTurn()
        }
    }
    let board = Board()
    var game:GameState! {
        didSet {
            gameStateLabel.text = game.currPlayer.rawValue + ":" + playerType[game.currPlayer]!.rawValue.uppercased() + " to " + game.mode.rawValue
            if let winner = game.checkWinner {
                let alert = UIAlertController(title: "Game Over", message: "\(winner.rawValue) wins!", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "New Game!", style: .default, handler: { action in
                    self.newGame([
                        GamePlayer.x: GamePlayerType.human,
                        GamePlayer.o: GamePlayerType.ai
                        ])
                }))
                present(alert, animated: true, completion: nil)
            } else {
                if currentPlane != nil {
                    newTurn()
                }
            }
        }
    }
    var figures:[String:SCNNode] = [:]
    var lightNode:SCNNode?
    var floorNode:SCNNode?
    var draggingFrom:GamePosition? = nil
    var draggingFromPosition:SCNVector3? = nil
    var recentVirtualObjectDistances = [CGFloat]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        game = GameState()
        sceneView.delegate = self
        sceneView.antialiasingMode = .multisampling4X
        sceneView.automaticallyUpdatesLighting = false
        let tap = UITapGestureRecognizer()
        tap.addTarget(self, action: #selector(makeTap))
        sceneView.addGestureRecognizer(tap)
    }
    
    func enableEnvironmentMapWithIntensity(_ intensity: CGFloat) {
        if sceneView.scene.lightingEnvironment.contents == nil {
            if let environmentMap = UIImage(named: "Media.scnassets/environment_blur.exr") {
                sceneView.scene.lightingEnvironment.contents = environmentMap
            }
        }
        sceneView.scene.lightingEnvironment.intensity = intensity
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = .horizontal
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }

    private func newGame(_ players:[GamePlayer:GamePlayerType]) {
         playerType = players
         game = GameState()
         cleanFigures()
         figures.removeAll()
    }
    
    private func reset() {
        let alert = UIAlertController()
        alert.addAction(UIAlertAction(title: "HUMAN VS AI Player", style: .default, handler: { action in
            self.newGame([
                GamePlayer.x: GamePlayerType.human,
                GamePlayer.o: GamePlayerType.ai
                ])
        }))
        present(alert, animated: true, completion: nil)
    }
    
    private func newTurn() {
        guard playerType[game.currPlayer]! == .ai else { return }
        DispatchQueue.global(qos: DispatchQoS.QoSClass.background).async {
            let action = GameAI(game: self.game).nextAction
            DispatchQueue.main.async {
                guard let newGameState = self.game.makeMove(action: action) else { fatalError() }
                let updateGameState = {
                    DispatchQueue.main.async {
                        self.game = newGameState
                    }
                }
                switch action {
                case .put(let at):
                    self.put(piece: Figure.figure(for: self.game.currPlayer), at: at,completionHandler: updateGameState)
                case .move(let from, let to):
                    self.move(from: from,to: to,completionHandler: updateGameState)
                }
            }
        }
    }
    
    private func cleanFigures() {
        for (_, figure) in figures {
            figure.removeFromParentNode()
        }
    }
    
    private func restoreGame(at position:SCNVector3) {
        board.node.position = position
        sceneView.scene.rootNode.addChildNode(board.node)
        let light = SCNLight()
        light.type = .directional
        light.castsShadow = true
        light.shadowRadius = 200
        light.shadowColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
        light.shadowMode = .deferred
        let constraint = SCNLookAtConstraint(target: board.node)
        lightNode = SCNNode()
        lightNode!.light = light
        lightNode!.position = SCNVector3(position.x + 10, position.y + 10, position.z)
        lightNode!.constraints = [constraint]
        sceneView.scene.rootNode.addChildNode(lightNode!)
 
        for (key, figure) in figures {
            let drawXY = key.components(separatedBy: "x")
            guard drawXY.count == 2,
                  let x = Int(drawXY[0]),
                  let y = Int(drawXY[1]) else { fatalError() }
            put(piece: figure,
                at: (x: x,
                     y: y))
        }
    }
    
    private func groundPositionFrom(location:CGPoint) -> SCNVector3? {
        let results = sceneView.hitTest(location,
                                        types: ARHitTestResult.ResultType.existingPlaneUsingExtent)
        
        guard results.count > 0 else { return nil }
        
        return SCNVector3.positionFromTransform(results[0].worldTransform)
    }
    
    private func anyPlaneFrom(location:CGPoint) -> (SCNNode, SCNVector3)? {
        let results = sceneView.hitTest(location,
                                        types: ARHitTestResult.ResultType.existingPlaneUsingExtent)
        
        guard results.count > 0,
              let anchor = results[0].anchor,
              let node = sceneView.node(for: anchor) else { return nil }
        
        return (node, SCNVector3.positionFromTransform(results[0].worldTransform))
    }
    
    private func squareFrom(location:CGPoint) -> ((Int, Int), SCNNode)? {
        guard let _ = currentPlane else { return nil }
        
        let hitResults = sceneView.hitTest(location, options: [SCNHitTestOption.firstFoundOnly: false,
                                                               SCNHitTestOption.rootNode:       board.node])
        
        for result in hitResults {
            if let square = board.nodeToSquare[result.node] {
                return (square, result.node)
            }
        }
        
        return nil
    }
    
    private func revertDrag() {
        if let draggingFrom = draggingFrom {
            
            let restorePosition = sceneView.scene.rootNode.convertPosition(draggingFromPosition!, from: board.node)
            let action = SCNAction.move(to: restorePosition, duration: 0.3)
            figures["\(draggingFrom.x)x\(draggingFrom.y)"]?.runAction(action)
            
            self.draggingFrom = nil
            self.draggingFromPosition = nil
        }
    }
    
    @objc func makeTap(_ sender:UITapGestureRecognizer) {
        let location = sender.location(in: sceneView)
        
        guard let _ = currentPlane else {
            guard let newPlaneData = anyPlaneFrom(location: location) else { return }
            
            let floor = SCNFloor()
            floor.reflectivity = 0
            let material = SCNMaterial()
            material.diffuse.contents = UIColor.white

            material.colorBufferWriteMask = SCNColorMask(rawValue: 0)
            floor.materials = [material]
            
            floorNode = SCNNode(geometry: floor)
            floorNode!.position = newPlaneData.1
            sceneView.scene.rootNode.addChildNode(floorNode!)
            
            self.currentPlane = newPlaneData.0
            restoreGame(at: newPlaneData.1)
            
            return
        }
        
        // otherwise tap to place board piece.. (if we're in "put" mode)
        guard case .put = game.mode,
              playerType[game.currPlayer]! == .human else { return }
        
        if let squareData = squareFrom(location: location),
           let newGameState = game.makeMove(action: .put(at: (x: squareData.0.0,
                                                             y: squareData.0.1))) {
            
            put(piece: Figure.figure(for: game.currPlayer),
                at: squareData.0) {
                    DispatchQueue.main.async {
                        self.game = newGameState
                    }
            }
            
            
        }
    }
    
    private func move(from:GamePosition,
                      to:GamePosition,
                      completionHandler: (() -> Void)? = nil) {
        
        let fromSquareId = "\(from.x)x\(from.y)"
        let toSquareId = "\(to.x)x\(to.y)"
        guard let piece = figures[fromSquareId],
              let rawDestinationPosition = board.squareToPosition[toSquareId]  else { fatalError() }
        
        let destinationPosition = sceneView.scene.rootNode.convertPosition(rawDestinationPosition,
                                                                           from: board.node)
        figures[toSquareId] = piece
        figures[fromSquareId] = nil
        
        // create drag and drop animation
        let pickUpAction = SCNAction.move(to: SCNVector3(piece.position.x, piece.position.y + Float(Dimensions.DRAG_LIFTOFF), piece.position.z),
                                          duration: 0.25)
        let moveAction = SCNAction.move(to: SCNVector3(destinationPosition.x, destinationPosition.y + Float(Dimensions.DRAG_LIFTOFF), destinationPosition.z),
                                        duration: 0.5)
        let dropDownAction = SCNAction.move(to: destinationPosition,
                                            duration: 0.25)
        
        piece.runAction(pickUpAction) {
            piece.runAction(moveAction) {
                piece.runAction(dropDownAction,
                                completionHandler: completionHandler)
            }
        }
    }
    
    /// renders user and AI insert of piece
    private func put(piece:SCNNode,
                     at position:GamePosition,
                     completionHandler: (() -> Void)? = nil) {
        let squareId = "\(position.x)x\(position.y)"
        guard let squarePosition = board.squareToPosition[squareId] else { fatalError() }
        
        piece.opacity = 0

        piece.position = sceneView.scene.rootNode.convertPosition(squarePosition,
                                                                  from: board.node)
        sceneView.scene.rootNode.addChildNode(piece)
        figures[squareId] = piece
        
        let action = SCNAction.fadeIn(duration: 0.5)
        piece.runAction(action,
                        completionHandler: completionHandler)
    }
    
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
            DispatchQueue.main.async {
            if let lightEstimate = self.sceneView.session.currentFrame?.lightEstimate {
                self.enableEnvironmentMapWithIntensity(lightEstimate.ambientIntensity / 50)
            } else {
                self.enableEnvironmentMapWithIntensity(25)
            }
        }
    }
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        planeCount += 1
    }
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {

    }
    func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
        if node == currentPlane {
            cleanFigures()
            lightNode?.removeFromParentNode()
            lightNode = nil
            floorNode?.removeFromParentNode()
            floorNode = nil
            board.node.removeFromParentNode()
            currentPlane = nil
        }
        if planeCount > 0 {
            planeCount -= 1
        }
    }
    
}

