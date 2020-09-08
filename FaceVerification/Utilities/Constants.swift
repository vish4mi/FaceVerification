//
//  Constants.swift
//  FaceVerification
//
//  Created by Vishal Bhadade on 06/09/20.
//  Copyright © 2020 VB. All rights reserved.
//

import Foundation

struct SegueName {
    static let CaptureViewController = "captureVCSegue"
    static let ReviewViewController = "reviewVCSegue"
}

struct VCIdentifier {
    static let CaptureScreenIdentifier = "captureViewController"
    static let ReviewScreenIdentifier = "reviewViewController"
}

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
