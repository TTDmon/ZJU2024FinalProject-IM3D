//
//  ContentViewModel.swift
//  IOSCapture
//
//  Created by YJJ on 2022/7/16.
//

import Foundation
import UIKit
import CoreVideo
import MediaPlayer
import CoreGraphics
import AVFoundation
import ARKit
import RealityKit
import CoreMotion
import Atomics
import VideoToolbox

class ContentViewModel : ObservableObject {
    
    var capturedPhoto : UIImage?
    var error : Error?
    private var captureViewModel : CaptureViewModel!
    var photonumber:Int=0
    
    init() {
        print("content view model init")
        self.captureViewModel=CaptureViewModel(viewModel: self)
    }
    
    deinit {
        
    }
    func PhotoNubmerAdd(){
        self.photonumber+=1
    }
    
}

