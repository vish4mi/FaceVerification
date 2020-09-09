//
//  ViewController.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 29/08/20.
//  Copyright © 2020 VB. All rights reserved.
//

import UIKit


class FCVRHomeViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }

    @IBAction func startCaptureButtonClicked(_ sender: UIButton) {
        if #available(iOS 11, *) {
            self.performSegue(withIdentifier: SegueName.CaptureViewController, sender: self)
        } else {
            let alert = UIAlertController.init(title: "Support Issue", message: "Your device does not support this feature, please update your device to iOS version 11 or higher", preferredStyle: .alert)
            let action = UIAlertAction.init(title: "Ok", style: .default, handler: nil)
            alert.addAction(action)
            self.present(alert, animated: true, completion: nil)
        }
    }
    
}

