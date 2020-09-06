//
//  FCVRCaptureViewController.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 29/08/20.
//  Copyright © 2020 VB. All rights reserved.
//

import UIKit
import AVFoundation

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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        // Do any additional setup after loading the view.
    }
    
    func configureView() {
        configureCaptureView()
        prepare { (error) in
            if let error = error {
                print(error)
            }
        }
    }
    
    func configureCaptureView() {
        self.actionButton.layer.cornerRadius = self.actionButton.bounds.width/2
//        self.captureView.layer.borderWidth = 2.0
//        self.captureView.layer.borderColor = UIColor.green.cgColor
//        
//        self.captureView.backgroundColor = .yellow
    }
    
    @IBAction func cancelButtonClicked(_ sender: UIButton) {
    }
    
    @IBAction func actionButtonClicked(_ sender: UIButton) {
        sender.isEnabled = false
        
        if #available(iOS 10, *) {
            let photoSettings = AVCapturePhotoSettings()
            photoSettings.isAutoStillImageStabilizationEnabled = true
            //photoSettings.isHighResolutionPhotoEnabled = true
            photoSettings.flashMode = .auto
            
            if let photoOutput = self.photoOutput, photoOutput.isKind(of: AVCapturePhotoOutput.self) {
                let output: AVCapturePhotoOutput = photoOutput as! AVCapturePhotoOutput
                output.capturePhoto(with: photoSettings, delegate: self)
            }
        } else {
            
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueName.ReviewViewController {
            let reviewVC = segue.destination as! FCVRReviewViewController
            reviewVC.reviewImage = self.capturedImage
        }
    }
    
}

extension FCVRCaptureViewController {
    func prepare(completionHandler: @escaping (Error?) -> Void) {
        
        func createCaptureSession() {
            self.captureSession = AVCaptureSession()
        }
        
        func configureCaptureDevices() throws {
            if #available(iOS 10.0, *) {
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
            } else {
                // Fallback on earlier versions
                let cameras = AVCaptureDevice.devices(for: AVMediaType.video)
                
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
            
        }
        
        func configureDeviceInputs() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            if let rearCamera = self.rearCamera {
                self.rearCameraInput = try AVCaptureDeviceInput(device: rearCamera)
                
                if captureSession.canAddInput(self.rearCameraInput!) { captureSession.addInput(self.rearCameraInput!) }
                
                self.currentCameraPosition = .rear
            }
                
            else if let frontCamera = self.frontCamera {
                self.frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                
                if captureSession.canAddInput(self.frontCameraInput!) { captureSession.addInput(self.frontCameraInput!) }
                else { throw CameraControllerError.inputsAreInvalid }
                
                self.currentCameraPosition = .front
            }
                
            else { throw CameraControllerError.noCamerasAvailable }
        }
        
        func configurePhotoOutput() throws {
            guard let captureSession = self.captureSession else { throw CameraControllerError.captureSessionIsMissing }
            
            if #available(iOS 10.0, *) {
                self.photoOutput = AVCapturePhotoOutput()
                self.photoOutput?.setPreparedPhotoSettingsArray([AVCapturePhotoSettings(format: [AVVideoCodecKey : AVVideoCodecJPEG])], completionHandler: nil)
                if captureSession.canAddOutput(self.photoOutput as! AVCapturePhotoOutput) {
                    captureSession.addOutput(self.photoOutput as! AVCapturePhotoOutput)
                }
                
            } else {
                setupOldCamera()
            }
            
            captureSession.startRunning()
        }
        
        DispatchQueue(label: "prepare").async {
            do {
                createCaptureSession()
                try configureCaptureDevices()
                try configureDeviceInputs()
                try configurePhotoOutput()
            }
                
            catch {
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

extension FCVRCaptureViewController {
    enum CameraControllerError: Swift.Error {
        case captureSessionAlreadyRunning
        case captureSessionIsMissing
        case inputsAreInvalid
        case invalidOperation
        case noCamerasAvailable
        case unknown
    }
    
    public enum CameraPosition {
        case front
        case rear
    }
}

@available(iOS 10.0, *)
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

extension FCVRCaptureViewController: UIImagePickerControllerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {
    // iOS 9 setup
    func setupOldCamera() {
        let cameraSession = AVCaptureSession()
        cameraSession.sessionPreset = AVCaptureSession.Preset.high
        
        let captureDevice = (AVCaptureDevice.default(for: AVMediaType.video)).flatMap({$0})
        
        if let aCaptureDevice = captureDevice {
            do {
                let deviceInput = try AVCaptureDeviceInput(device: aCaptureDevice)
                
                cameraSession.beginConfiguration() // 1
                
                if (cameraSession.canAddInput(deviceInput) == true) {
                    cameraSession.addInput(deviceInput)
                }
                
                let dataOutput = AVCaptureVideoDataOutput() // 2
                
                dataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String) : NSNumber(value: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange as UInt32)] // 3
                
                dataOutput.alwaysDiscardsLateVideoFrames = true // 4
                
                if (cameraSession.canAddOutput(dataOutput) == true) {
                    cameraSession.addOutput(dataOutput)
                }
                
                cameraSession.commitConfiguration() //5
                
                let queue = DispatchQueue(label: "com.invasivecode.videoQueue") // 6
                dataOutput.setSampleBufferDelegate(self, queue: queue) // 7
                
            } catch let error as NSError {
                NSLog("\(error), \(error.localizedDescription)")
            }
        }
        
    }
    
    func captureOutput(_ captureOutput: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
     
    }
}
