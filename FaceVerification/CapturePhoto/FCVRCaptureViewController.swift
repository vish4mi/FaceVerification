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
    // Main view for showing camera content.
    @IBOutlet weak var captureView: UIView!
    @IBOutlet weak var captureInfoLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBOutlet weak var actionButton: UIButton!
    
    private let captureSession = AVCaptureSession()
    private lazy var previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private var drawings: [CAShapeLayer] = []
    var capturePhotoOutput: AVCapturePhotoOutput?
    var shouldEnableCapture = false
    var boundingBox: CGRect?
    var capturedImage: UIImage?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.configureView()
        self.addCameraInput()
        if self.capturePhotoOutput == nil {
            self.capturePhotoOutput = self.configurePhotoOutput(for: self.captureSession)
        }
        self.showCameraFeed()
        self.getCameraFrames()
        self.captureSession.startRunning()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        configurePreviewLayer()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == SegueName.ReviewViewController {
            if let reviewVC = segue.destination as? FCVRReviewViewController {
                if let image = self.capturedImage, let box = self.boundingBox {
                    reviewVC.reviewImage = image
                    reviewVC.boundingBox = box
                }
            }
            
        }
    }
    
    func configureView() {
        self.actionButton.isEnabled = false
    }
    
    private func addCameraInput() {
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front).devices.first else {
                fatalError("No back camera device found, please make sure to run SimpleLaneDetection in an iOS device and not a simulator")
        }
        let cameraInput = try! AVCaptureDeviceInput(device: device)
        self.captureSession.addInput(cameraInput)
    }
    
    private func showCameraFeed() {
        self.previewLayer.videoGravity = .resizeAspectFill
        configurePreviewLayer()
        self.captureView.layer.addSublayer(self.previewLayer)
    }
    
    func configurePreviewLayer() {
        self.previewLayer.frame = self.captureView.bounds
        self.previewLayer.cornerRadius = self.captureView.bounds.width/2
        self.previewLayer.borderWidth = 2.0
        self.previewLayer.borderColor = UIColor.green.cgColor
    }
    
    private func getCameraFrames() {
        self.videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as NSString) : NSNumber(value: kCVPixelFormatType_32BGRA)] as [String : Any]
        self.videoDataOutput.alwaysDiscardsLateVideoFrames = true
        self.videoDataOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera_frame_processing_queue"))
        self.captureSession.addOutput(self.videoDataOutput)
        guard let connection = self.videoDataOutput.connection(with: AVMediaType.video),
            connection.isVideoOrientationSupported else { return }
        connection.videoOrientation = .portrait
    }
}

@available(iOS 11.0, *)
extension FCVRCaptureViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let frame = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            debugPrint("unable to get image from sample buffer")
            return
        }
        self.detectFace(in: frame)
    }
    
    private func detectFace(in image: CVPixelBuffer) {
        let faceDetectionRequest = VNDetectFaceLandmarksRequest(completionHandler: { (request: VNRequest, error: Error?) in
            DispatchQueue.main.async {
                if let results = request.results as? [VNFaceObservation] {
                    self.handleFaceDetectionResults(results)
                } else {
                    self.clearDrawings()
                }
            }
        })
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: image, orientation: .leftMirrored, options: [:])
        try? imageRequestHandler.perform([faceDetectionRequest])
    }
    
    private func handleFaceDetectionResults(_ observedFaces: [VNFaceObservation]) {
        
        self.clearDrawings()
        let facesBoundingBoxes: [CAShapeLayer] = observedFaces.flatMap({ (observedFace: VNFaceObservation) -> [CAShapeLayer] in
            let faceBoundingBoxOnScreen = self.previewLayer.layerRectConverted(fromMetadataOutputRect: observedFace.boundingBox) as CGRect
            let faceBoundingBoxPath = CGPath(rect: faceBoundingBoxOnScreen, transform: nil)
            let faceBoundingBoxShape = CAShapeLayer()
            faceBoundingBoxShape.path = faceBoundingBoxPath
            faceBoundingBoxShape.fillColor = UIColor.clear.cgColor
            faceBoundingBoxShape.strokeColor = UIColor.clear.cgColor
            var newDrawings = [CAShapeLayer]()
            newDrawings.append(faceBoundingBoxShape)
            return newDrawings
        })
        facesBoundingBoxes.forEach({ faceBoundingBox in self.captureView.layer.addSublayer(faceBoundingBox) })
        self.drawings = facesBoundingBoxes
        self.configureCapture(for: observedFaces)
    }
    
    private func clearDrawings() {
        self.drawings.forEach({ drawing in drawing.removeFromSuperlayer() })
    }
}

@available(iOS 11.0, *)
extension FCVRCaptureViewController: AVCapturePhotoCaptureDelegate {
    
    @IBAction func cancelButtonClicked(_ sender: UIButton) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func captureButtonClicked(_ sender: UIButton) {
        
        guard let capturePhotoOutput = self.capturePhotoOutput else {
            return
        }
        
        // Get an instance of AVCapturePhotoSettings class
        let photoSettings = AVCapturePhotoSettings()
        let previewPixelType = photoSettings.availablePreviewPhotoPixelFormatTypes.first!
        let previewFormat = [
            kCVPixelBufferPixelFormatTypeKey as String: previewPixelType,
            kCVPixelBufferWidthKey as String: 160,
            kCVPixelBufferHeightKey as String: 160
        ]
        photoSettings.previewPhotoFormat = previewFormat
        // Set photo settings for our need
        photoSettings.isAutoStillImageStabilizationEnabled = true
        photoSettings.isHighResolutionPhotoEnabled = true
        photoSettings.flashMode = .auto
        
        // Call capturePhoto method by passing our photo settings and a delegate implementing AVCapturePhotoCaptureDelegate
        capturePhotoOutput.capturePhoto(with: photoSettings, delegate: self)
    }
    
    func configurePhotoOutput(for captureSession: AVCaptureSession) -> AVCapturePhotoOutput? {
        // get an instance of AVCapturePhotoOutput class
        let capturePhotoOutput = AVCapturePhotoOutput()
        capturePhotoOutput.isHighResolutionCaptureEnabled = true
        if self.captureSession.canAddOutput(capturePhotoOutput) {
            self.captureSession.addOutput(capturePhotoOutput)
        }
        return capturePhotoOutput
    }
    
    func photoOutput(_ captureOutput: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                     previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     bracketSettings: AVCaptureBracketedStillImageSettings?,
                     error: Error?) {
        // Make sure we get some photo sample buffer
        guard error == nil,
            let photoSampleBuffer = photoSampleBuffer else {
                print("Error capturing photo: \(String(describing: error))")
                return
        }
        
        // Convert photo same buffer to a jpeg image data by using AVCapturePhotoOutput
        guard let imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer) else {
            return
        }
        
        // Initialise an UIImage with our image data
        let capturedImage = UIImage.init(data: imageData , scale: 1.0)
        if let _ = capturedImage, let _ = self.boundingBox {
            //self.cropImage(with: image, and: box)
            self.capturedImage = capturedImage
            //self.cropImage(with: image, and: box)
            self.performSegue(withIdentifier: SegueName.ReviewViewController, sender: self)
        }
    }
    
    func configureCapture(for observedFaces: [VNFaceObservation]) {
        var shouldEnableCapture = false
        
        let observedFace = observedFaces.compactMap({$0}).first
        if let firstFace = observedFace {
            
            if #available(iOS 12.0, *) {
                if firstFace.yaw == 0 {
                    shouldEnableCapture = true
                }
            } else {
                // Fallback on earlier versions
                if firstFace.confidence > 0.5 {
                    shouldEnableCapture = true
                    self.boundingBox = firstFace.boundingBox
                }
            }
        }
        
        if self.shouldEnableCapture != shouldEnableCapture {
            DispatchQueue.main.async {
                self.actionButton.isEnabled = shouldEnableCapture
            }
            self.shouldEnableCapture = shouldEnableCapture
        }
    }
    
    //    func cropImage(with image: UIImage, and rect: CGRect) {
    //
    //        var personImage = CIImage(image: image)
    //
    //        //let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyLow]
    //        //let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
    //        // This will just take the first detected face but you can do something more sophisticated
    ////        guard let face = faceDetector?.features(in: personImage).first as? CIFaceFeature else { return }
    //
    //        // Make the facial rect a square so it will mask nicely to a circle (may not be strictly necessary as `CIFaceFeature` bounds is typically a square)
    //        var aRect = rect
    //        aRect.size.height = max(rect.height, rect.width)
    //        aRect.size.width = max(rect.height, rect.width)
    //        aRect = rect.insetBy(dx: -30, dy: -30) // Adds padding around the face so it's not so tightly cropped
    //
    //        // Crop to the face detected
    //        guard let aPersonImage = personImage else {
    //            return
    //        }
    //        personImage = aPersonImage.cropped(to: aRect)
    //
    //        // Set the new cropped image as the image view image
    //        guard let personCIImage = personImage else {
    //            return
    //        }
    //
    //        let croppedImage = UIImage(ciImage: personCIImage)
    //        // Save our captured image to photos album
    //        UIImageWriteToSavedPhotosAlbum(croppedImage, nil, nil, nil)
    //    }
}
