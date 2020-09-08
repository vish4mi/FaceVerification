//
//  FCVRCaptureViewController.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 29/08/20.
//  Copyright © 2020 VB. All rights reserved.
//

import UIKit
import AVFoundation
import ARKit
import Vision

@available(iOS 11.0, *)
class FCVRCaptureViewController: UIViewController {
    
    @IBOutlet weak var topBarView: UIView!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var actionView: UIView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var captureView: UIView!
    @IBOutlet weak var captureInfoLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBOutlet weak var actionButton: UIButton!
    
    var captureSession: AVCaptureSession?
    
    var currentCameraPosition: CameraPosition?
    
    var frontCamera: AVCaptureDevice?
    var frontCameraInput: AVCaptureDeviceInput?
    
    var photoOutput: AnyObject?
    
    var rearCamera: AVCaptureDevice?
    var rearCameraInput: AVCaptureDeviceInput?
    var capturedImage: UIImage?
    var sceneView: ARSCNView?
    var realFaceScores = [String: Int]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureARView()
        configureView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startARSession()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView?.session.pause()
    }
    
    func configureView() {
        configureCaptureView()
        prepare { (error) in
            if let anError = error {
                print(anError)
            }
        }
    }
    
    func configureCaptureView() {
        self.actionButton.layer.cornerRadius = self.actionButton.bounds.width/2
        self.actionButton.isEnabled = false
    }
    
    @available(iOS 11.0, *)
    func configureARView() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        
        let sceneView = ARSCNView(frame: self.captureView.bounds)
        sceneView.layer.cornerRadius = self.captureView.bounds.width/2
        sceneView.frame = self.captureView.bounds
        self.captureView.addSubview(sceneView)// add the scene to the subview
        sceneView.delegate = self // Setting the delegate for our view controller
        //sceneView.showsStatistics = true // Show statistics
        //sceneView.snapshot()
        self.sceneView = sceneView
    }
    
    func startARSession() {
        // Create a session configuration
        let configuration = ARFaceTrackingConfiguration()
        
        configuration.isLightEstimationEnabled = true
        
        // Run the view's session
        sceneView?.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    @IBAction func cancelButtonClicked(_ sender: UIButton) {
    }
    
    @IBAction func actionButtonClicked(_ sender: UIButton) {
        let photoSettings = AVCapturePhotoSettings()
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.flashMode = .auto
        
        if let photoOutput = self.photoOutput, photoOutput.isKind(of: AVCapturePhotoOutput.self) {
            let output: AVCapturePhotoOutput = photoOutput as! AVCapturePhotoOutput
            output.capturePhoto(with: photoSettings, delegate: self)
        }
    }
    
    func enableCaptureButton() {
        actionButton.isEnabled = true
        sceneView?.session.pause()
        prepare { (error) in
            if let anError = error {
                print("Camera session can not be started: \(anError)")
            }
        }
        Timer.scheduledTimer(withTimeInterval: 5, repeats: false, block: { _ in
            self.actionButton.isEnabled = false
            self.realFaceScores.removeAll()
            self.startARSession()
        })
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueName.ReviewViewController {
            let reviewVC = segue.destination as! FCVRReviewViewController
            reviewVC.reviewImage = self.capturedImage
        }
    }
    
}

@available(iOS 11.0, *)
extension FCVRCaptureViewController {
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        func configureCaptureDevices() throws {
            let session = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .front)
            let cameras = session.devices.compactMap { $0 }
            
            let previewLayer =  AVCaptureVideoPreviewLayer(session: self.captureSession!)
            previewLayer.videoGravity = AVLayerVideoGravity.resize
            
            DispatchQueue.main.async {
                previewLayer.bounds = CGRect(x: 0, y: 0, width: self.captureView.bounds.width, height: self.captureView.bounds.height)
                previewLayer.position = CGPoint(x: self.captureView.bounds.midX, y: self.captureView.bounds.midY)
                previewLayer.cornerRadius = self.captureView.bounds.width/2
                previewLayer.borderWidth = 2.0
                previewLayer.borderColor = UIColor.green.cgColor
                self.captureView.layer.addSublayer(previewLayer)
            }
            
            for camera in cameras {
                if camera.position == .front {
                    self.frontCamera = camera
                }
                if camera.position == .back {
                    self.rearCamera = camera
                    try camera.lockForConfiguration()
                    camera.focusMode = .autoFocus
                    camera.unlockForConfiguration()
                }
            }
        }
        
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                if captureSession.canAddInput(self.rearCameraInput!) {
                    captureSession.addInput(self.rearCameraInput!)
                }
                self.currentCameraPosition = .rear
            } else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if captureSession.canAddInput(self.frontCameraInput!) {
                    captureSession.addInput(self.frontCameraInput!)
                } else {
                    throw CameraControllerError.inputsAreInvalid
                }
                self.currentCameraPosition = .front
            } else {
                throw CameraControllerError.noCamerasAvailable
            }
        }
        
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else {
                throw CameraControllerError.captureSessionIsMissing
            }
            
            self.photoOutput = AVCapturePhotoOutput()
            self.photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
            if captureSession.canAddOutput(self.photoOutput as! AVCapturePhotoOutput) {
                captureSession.addOutput(self.photoOutput as! AVCapturePhotoOutput)
            }
            
            captureSession.startRunning()
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                //try configurePhotoOutput()
            } catch {
                DispatchQueue.main.async {
                    completionHandler(error)
                }
                return
            }
            
            DispatchQueue.main.async {
                completionHandler(nil)
            }
        }
    }
}

@available(iOS 11.0, *)
extension FCVRCaptureViewController: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        
    }
    
    func photoOutput(_ captureOutput: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                     previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     bracketSettings: AVCaptureBracketedStillImageSettings?,
                     error: Error?) {
        // Make sure we get some photo sample buffer
        guard error == nil, let photoSampleBuffer = photoSampleBuffer else {
            print("Error capturing photo: \(String(describing: error))")
            return
        }
        
        // Convert photo same buffer to a jpeg image data by using AVCapturePhotoOutput
        guard let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer) else {
            return
        }
        
        // Initialise an UIImage with our image data
        let capturedImage = UIImage.init(data: imageData , scale: 1.0)
        if let image = capturedImage {
            self.capturedImage = image
            self.performSegue(withIdentifier: SegueName.ReviewViewController, sender: self)
        }
    }
}

@available(iOS 11.0, *)
extension FCVRCaptureViewController: UIImagePickerControllerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer: CVPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let request = VNDetectFaceRectanglesRequest { (req, err) in
            
            if let err = err {
                print("Failed to detect faces:", err)
                return
            }
            
            DispatchQueue.main.async {
                if let results = req.results {
                    //self.numberOfFaces.text = "\(results.count) face(s)"
                    print(results)
                }
            }
        }
        
        DispatchQueue.global(qos: .userInteractive).async {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            do {
                try handler.perform([request])
            } catch let reqErr {
                print("Failed to perform request:", reqErr)
            }
        }
    }
    
}

@available(iOS 11.0, *)
extension FCVRCaptureViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        
        guard let sceneView = self.sceneView else {
            return nil
        }
        
        guard let device = sceneView.device else {
            return nil
        }
        
        let faceGeometry = ARSCNFaceGeometry(device: device)
        
        let node = SCNNode(geometry: faceGeometry)
        
        node.geometry?.firstMaterial?.fillMode = .lines
        
        return node
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        guard let faceAnchor = anchor as? ARFaceAnchor,
            let faceGeometry = node.geometry as? ARSCNFaceGeometry else {
                return
        }
        
        faceGeometry.update(from: faceAnchor.geometry)
        expression(anchor: faceAnchor)
    }
    
    func expression(anchor: ARFaceAnchor) {
        let blendShapes: [ARFaceAnchor.BlendShapeLocation:Any] = anchor.blendShapes
        
        //        guard let browDownLeft = blendShapes[.browDownLeft] as? Float else {return}
        //        guard let browDownRight = blendShapes[.browDownRight] as? Float else {return}
        //        guard let browInnerUp = blendShapes[.browInnerUp] as? Float else {return}
        //        guard let browOuterUpLeft = blendShapes[.browOuterUpLeft] as? Float else {return}
        //        guard let browOuterUpRight = blendShapes[.browOuterUpRight] as? Float else {return}
        //        guard let cheekPuff = blendShapes[.cheekPuff] as? Float else {return}
        //        guard let cheekSquintLeft = blendShapes[.cheekSquintLeft] as? Float else {return}
        //        guard let cheekSquintRight = blendShapes[.cheekSquintRight] as? Float else {return}
        //        guard let eyeBlinkLeft = blendShapes[.eyeBlinkLeft] as? Float else {return}
        //        guard let eyeBlinkRight = blendShapes[.eyeBlinkRight] as? Float else {return}
        //        guard let eyeLookDownLeft = blendShapes[.eyeLookDownLeft] as? Float else {return}
        //        guard let eyeLookDownRight = blendShapes[.eyeLookDownRight] as? Float else {return}
        //        guard let eyeLookInLeft = blendShapes[.eyeLookInLeft] as? Float else {return}
        //        guard let eyeLookInRight = blendShapes[.eyeLookInRight] as? Float else {return}
        //        guard let eyeLookOutLeft = blendShapes[.eyeLookOutLeft] as? Float else {return}
        //        guard let eyeLookOutRight = blendShapes[.eyeLookOutRight] as? Float else {return}
        //        guard let eyeLookUpLeft = blendShapes[.eyeLookUpLeft] as? Float else {return}
        //        guard let eyeLookUpRight = blendShapes[.eyeLookUpRight] as? Float else {return}
        //        guard let eyeSquintLeft = blendShapes[.eyeSquintLeft] as? Float else {return}
        //        guard let eyeSquintRight = blendShapes[.eyeSquintRight] as? Float else {return}
        //        guard let eyeWideLeft = blendShapes[.eyeWideLeft] as? Float else {return}
        //        guard let eyeWideRight = blendShapes[.eyeWideRight] as? Float else {return}
        //        guard let jawForward = blendShapes[.jawForward] as? Float else {return}
        //        guard let jawLeft = blendShapes[.jawLeft] as? Float else {return}
        //        guard let jawOpen = blendShapes[.jawOpen] as? Float else {return}
        //        guard let jawRight = blendShapes[.jawRight] as? Float else {return}
        //        guard let mouthClose = blendShapes[.mouthClose] as? Float else {return}
        //        guard let mouthDimpleLeft = blendShapes[.mouthDimpleLeft] as? Float else {return}
        //        guard let mouthDimpleRight = blendShapes[.mouthDimpleRight] as? Float else {return}
        //        guard let mouthFrownLeft = blendShapes[.mouthFrownLeft] as? Float else {return}
        //        guard let mouthFrownRight = blendShapes[.mouthFrownRight] as? Float else {return}
        //        guard let mouthFunnel = blendShapes[.mouthFunnel] as? Float else {return}
        //        guard let mouthLeft = blendShapes[.mouthLeft] as? Float else {return}
        //        guard let mouthLowerDownLeft = blendShapes[.mouthLowerDownLeft] as? Float else {return}
        //        guard let mouthLowerDownRight = blendShapes[.mouthLowerDownRight] as? Float else {return}
        //        guard let mouthPressLeft = blendShapes[.mouthPressLeft] as? Float else {return}
        //        guard let mouthPressRight = blendShapes[.mouthPressRight] as? Float else {return}
        //        guard let mouthPucker = blendShapes[.mouthPucker] as? Float else {return}
        //        guard let mouthRight = blendShapes[.mouthRight] as? Float else {return}
        //        guard let mouthRollLower = blendShapes[.mouthRollLower] as? Float else {return}
        //        guard let mouthRollUpper = blendShapes[.mouthRollUpper] as? Float else {return}
        //        guard let mouthShrugLower = blendShapes[.mouthShrugLower] as? Float else {return}
        //        guard let mouthShrugUpper = blendShapes[.mouthShrugUpper] as? Float else {return}
        //        guard let mouthSmileLeft = blendShapes[.mouthSmileLeft] as? Float else {return}
        //        guard let mouthSmileRight = blendShapes[.mouthSmileRight] as? Float else {return}
        //        guard let mouthStretchLeft = blendShapes[.mouthStretchLeft] as? Float else {return}
        //        guard let mouthStretchRight = blendShapes[.mouthStretchRight] as? Float else {return}
        //        guard let mouthUpperUpLeft = blendShapes[.mouthUpperUpLeft] as? Float else {return}
        //        guard let mouthUpperUpRight = blendShapes[.mouthUpperUpRight] as? Float else {return}
        //        guard let noseSneerLeft = blendShapes[.noseSneerLeft] as? Float else {return}
        //        guard let noseSneerRight = blendShapes[.noseSneerRight] as? Float else {return}
        //        if #available(iOS 12.0, *) {
        //            guard let tongueOut = blendShapes[.tongueOut] as? Float else {return}
        //        }
        
        //        if #available(iOS 12.0, *) {
        //            let tongue = anchor.blendShapes[.tongueOut]
        //            if tongue?.decimalValue ?? 0.0 > 0.1 {
        //                self.realFaceScore += 1
        //            }
        //        }
        //        if ((smileLeft?.decimalValue ?? 0.0) + (smileRight?.decimalValue ?? 0.0)) > 0.9 {
        //            self.realFaceScore += 1
        //        }
        //
        //        if cheekPuff?.decimalValue ?? 0.0 > 0.1 {
        //            self.realFaceScore += 1
        //        }
        
        //        for blendshape in blendShapes {
        //            le
        //            let shape = blendshape.key
        //            let value = blendshape.value as! NSNumber
        //            if value.floatValue > 0.7 {
        //                print(shape.rawValue, "--", value.floatValue * 100)
        //            }
        //        }
        
        guard let eyeBlinkLeft = blendShapes[.eyeBlinkLeft] as? Float else {
            return
        }
        guard let eyeBlinkRight = blendShapes[.eyeBlinkRight] as? Float else {
            return
        }
        //print("Left: ", eyeBlinkLeft, "::", "Right: ", eyeBlinkRight)
        if (0.1...0.3).contains(eyeBlinkLeft) && (0.1...0.3).contains(eyeBlinkRight) {
            realFaceScores["level1"] = 1
        } else if (0.3...0.6).contains(eyeBlinkLeft) && (0.3...0.6).contains(eyeBlinkRight) {
            realFaceScores["level2"] = 2
        } else if (0.6...1.0).contains(eyeBlinkLeft) && (0.6...1.0).contains(eyeBlinkRight) {
            realFaceScores["level3"] = 4
        }
        var faceScore = 0
        
        for (_, value) in realFaceScores {
            faceScore += value
        }
        
        if faceScore >= 5 {
            //print("Real face")
            DispatchQueue.main.async {
                if !self.actionButton.isEnabled {
                    self.enableCaptureButton()
                }
            }
        }
    }
}
