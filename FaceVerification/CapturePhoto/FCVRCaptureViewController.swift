//
//  FCVRCaptureViewController.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 29/08/20.
//  Copyright © 2020 VB. All rights reserved.
//

import UIKit

class FCVRCaptureViewController: UIViewController {

    @IBOutlet weak var topBarView: UIView!
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var actionView: UIView!
    
    @IBOutlet weak var cancelButton: UIButton!
    @IBOutlet weak var captureView: UIView!
    @IBOutlet weak var captureInfoLabel: UILabel!
    @IBOutlet weak var infoLabel: UILabel!
    
    @IBOutlet weak var actionButton: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        // Do any additional setup after loading the view.
    }
    
    func configureView() {
        self.captureView.layer.cornerRadius = self.captureView.frame.size.width/2
        self.captureView.layer.borderWidth = 2.0
        self.captureView.layer.borderColor = UIColor.green.cgColor
        
        self.captureView.backgroundColor = .yellow
    }
    
    @IBAction func cancelButtonClicked(_ sender: UIButton) {
    }
    
    @IBAction func actionButtonClicked(_ sender: Any) {
    }
    

}
