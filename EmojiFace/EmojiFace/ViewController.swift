//
//  ViewController.swift
//  EmojiFace
//
//  Created by Jake Holdom on 31/08/2019.
//  Copyright © 2019 Jake Holdom. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController {

    @IBOutlet weak var faceView: SCNView!
    @IBOutlet var trackingView: ARSCNView!
    
    var contentNode: SCNReferenceNode? // Reference to the .scn file
    var cameraPosition = SCNVector3Make(0, 15, 50) // Camera node to set position that the SceneKit is looking at the character
    let scene = SCNScene()
    let cameraNode = SCNNode()

    private lazy var model = contentNode!.childNode(withName: "model", recursively: true)! // Whole model including eyes
    private lazy var head = contentNode!.childNode(withName: "head", recursively: true)! // Contains blendshapes

    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        AVCaptureDevice.requestAccess(for: AVMediaType.video) { granted in
            if (granted) {
                // If access is granted, setup the main view
                DispatchQueue.main.sync {
                    self.setupFaceTracker()
                    self.sceneSetup()
                    self.createCameraNode()
                }
            } else {
                // If access is not granted, throw error and exit
                fatalError("This app needs Camera Access to function. You can grant access in Settings.")
            }
        }
    }
    
    func setupFaceTracker() {
        // Configure and start face tracking session
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        
        // Run ARSession and set delegate to self
        self.trackingView.session.run(configuration)
        self.trackingView.delegate = self
        self.trackingView.isHidden = true // Remove if you want to see the camera feed
    }
    
    func sceneSetup() {

        if let filePath = Bundle.main.path(forResource: "Smiley copy", ofType: "scn", inDirectory: "Models.scnassets") {
            let referenceURL = URL(fileURLWithPath: filePath)
            
            self.contentNode = SCNReferenceNode(url: referenceURL)
            self.contentNode?.load()
            self.head.morpher?.unifiesNormals = true // ensures the normals are not morphed but are recomputed after morphing the vertex instead. Otherwise the node has a low poly look.
            self.scene.rootNode.addChildNode(self.contentNode!)
        }
        self.faceView.autoenablesDefaultLighting = true

        // set the scene to the view
        self.faceView.scene = self.scene
        
        // allows the user to manipulate the camera
        self.faceView.allowsCameraControl = false

        // configure the view
        self.faceView.backgroundColor = .clear
    }
    
    func createCameraNode () {
        self.cameraNode.camera = SCNCamera()
        self.cameraNode.position = self.cameraPosition
        self.scene.rootNode.addChildNode(self.cameraNode)
        self.faceView.pointOfView = self.cameraNode
    }
    
    func calculateEulerAngles(_ faceAnchor: ARFaceAnchor) -> SCNVector3 {
        // Based on StackOverflow answer https://stackoverflow.com/a/53434356/3599895
        let projectionMatrix = self.trackingView.session.currentFrame?.camera.projectionMatrix(for: .portrait, viewportSize: self.faceView.bounds.size, zNear: 0.001, zFar: 1000)
        let viewMatrix = self.trackingView.session.currentFrame?.camera.viewMatrix(for: .portrait)
        
        let projectionViewMatrix = simd_mul(projectionMatrix!, viewMatrix!)
        let modelMatrix = faceAnchor.transform
        let mvpMatrix = simd_mul(projectionViewMatrix, modelMatrix)
        
        // This allows me to just get a .x .y .z rotation from the matrix, without having to do crazy calculations
        let newFaceMatrix = SCNMatrix4.init(mvpMatrix)
        let faceNode = SCNNode()
        faceNode.transform = newFaceMatrix
        let rotation = vector_float3(faceNode.worldOrientation.x, faceNode.worldOrientation.y, faceNode.worldOrientation.z)
        let yaw = (rotation.y*3)
        let pitch = (rotation.x*3)
        let roll = (rotation.z*1.5)
        
        return SCNVector3(pitch, yaw, roll)
    }
}

extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        
        DispatchQueue.main.async {
            let blendShapes = faceAnchor.blendShapes
            // This will only work correctly if the shape keys are given the exact same name as the blendshape names
            for (key, value) in blendShapes {
                if let fValue = value as? Float {
                    self.head.morpher?.setWeight(CGFloat(fValue), forTargetNamed: key.rawValue)
                }
            }
            self.model.eulerAngles = self.calculateEulerAngles(faceAnchor)
        }
    }
}
