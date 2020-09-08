//
//  FCVRReviewViewController.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 29/08/20.
//  Copyright © 2020 VB. All rights reserved.
//

import UIKit

class FCVRReviewViewController: UIViewController {
        
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var imageContainerView: UIView!
    @IBOutlet weak var actionView: UIView!
    
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var reviewImageView: UIImageView!
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    var boundingBox: CGRect?
    var reviewImage: UIImage?

    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    func configureView() {
        if let image = self.reviewImage {
            self.reviewImageView.image = image
        }
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureView()
        focusOnFace(in: self.reviewImageView)
    }
    
    @IBAction func saveButtonClicked(_ sender: UIButton) {
        // Save our captured image to photos album
        if let image = reviewImageView.image {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
    
    @IBAction func cancelButtonClicked(_ sender: UIButton) {
        
    }
    
    func focusOnFace(in imageView: UIImageView)
    {

        guard let image = self.reviewImage, var personImage = CIImage(image: image) else { return }

        let accuracy = [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        let faceDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options: accuracy)
        // This will just take the first detected face but you can do something more sophisticated
        guard let face = faceDetector?.features(in: personImage).first as? CIFaceFeature else { return }

        // Make the facial rect a square so it will mask nicely to a circle (may not be strictly necessary as `CIFaceFeature` bounds is typically a square)
        var rect = face.bounds
        rect.size.height = max(face.bounds.height, face.bounds.width)
        rect.size.width = max(face.bounds.height, face.bounds.width)
        rect = rect.insetBy(dx: -30, dy: -30) // Adds padding around the face so it's not so tightly cropped

        // Crop to the face detected
        personImage = personImage.cropped(to: rect)
        
        let originalOrientation = image.imageOrientation;

        // create the UIImage with the result from cgImage cropping and original orientation
        
        // Set the new cropped image as the image view image
        let ciContext = CIContext()
        let croppedCGImage = ciContext.createCGImage(personImage, from: personImage.extent)
        //uiImageView.image = UIImage(cgImage: cgImage) // work
        self.reviewImageView.image = UIImage(cgImage: croppedCGImage!, scale: (image.scale), orientation: originalOrientation)
    }
}
