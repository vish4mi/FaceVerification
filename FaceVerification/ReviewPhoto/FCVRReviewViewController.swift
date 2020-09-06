//
//  FCVRReviewViewController.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 29/08/20.
//  Copyright © 2020 VB. All rights reserved.
//

import UIKit

class FCVRReviewViewController: UIViewController {
    
    var reviewImage:UIImage?
    
    @IBOutlet weak var headerView: UIView!
    @IBOutlet weak var imageContainerView: UIView!
    @IBOutlet weak var actionView: UIView!
    
    @IBOutlet weak var headingLabel: UILabel!
    @IBOutlet weak var reviewImageView: UIImageView!
    
    @IBOutlet weak var saveButton: UIButton!
    @IBOutlet weak var cancelButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }
    
    func configureView() {
        if let image = self.reviewImage {
            self.reviewImageView.image = image
        }
    }
    
    @IBAction func saveButtonClicked(_ sender: UIButton) {
        // Save our captured image to photos album
        if let image = reviewImage {
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        }
    }
    
    @IBAction func cancelButtonClicked(_ sender: UIButton) {
        
    }
}
