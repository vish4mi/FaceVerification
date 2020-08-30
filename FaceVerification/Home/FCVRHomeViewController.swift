//
//  ViewController.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 29/08/20.
//  Copyright © 2020 VB. All rights reserved.
//

import UIKit

let CaptureScreenIdentifier = "captureViewController"
let ReviewScreenIdentifier = "reviewViewController"
let CaptureViewController = "captureVCSegue"
let ReviewViewController = "reviewVCSegue"

class FCVRHomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func startCaptureButtonClicked(_ sender: UIButton) {
        self.performSegue(withIdentifier: CaptureViewController, sender: self)
    }
    
}

