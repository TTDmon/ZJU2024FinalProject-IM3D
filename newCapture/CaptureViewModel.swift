//
//  CaptureViewModel.swift
//  PatternCapture
//
//  Created by YJJ on 2022/10/27.
//

import Foundation
import CoreVideo
import CoreGraphics
import CoreImage
import AVFoundation
import ARKit
import RealityKit
import CoreMotion
import Atomics
import VideoToolbox

class CaptureViewModel : NSObject, ObservableObject,AVCaptureFileOutputRecordingDelegate{
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        <#code#>
    }
    
    
    unowned private var viewModel : ContentViewModel
    
    private var cameraManager:CameraManager!
    //Frame index
    private(set) var frameIndex = 0
    private(set) var exposuretimes=[Float]()
    
    
    @Published private var _isCapturing = ManagedAtomic<Bool>(false)
    var isCapturing : Bool {
        set {
            self._isCapturing.store(newValue, ordering: .relaxed)
        }
        get {
            return self._isCapturing.load(ordering: .relaxed)
        }
    }
    
    //MotionManager instance
    private let motionManager = CMMotionManager()
    private let operationQueue = OperationQueue()
    
    
    //DiskWriter instance
    private let diskWriter = DiskWriter(
        baseDir: String(getCurrentTime()),
        photoDir: "Photos",
        videoFPS: 30,
        videoWidth: 1080,
        videoHeight: 1920
    )
    private var parameterSaved : Bool = false
    
    init(viewModel : ContentViewModel) {
        print("CaptureViewModel_init")
        self.viewModel = viewModel
        super.init()
        self.cameraManager=CameraManager()
        self.listenVolumeButton()
        guard self.cameraManager.error == nil else {
            DispatchQueue.main.async {
                self.viewModel.error = self.cameraManager.error
            }
            return
        }
        self.cameraManager.startVideoSession(delegate: self)
        self.diskWriter.startDump()
        self.startCapturing()
    }
    
    deinit {
        self.diskWriter.stopDump()
    }
    
    func listenVolumeButton() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
        } catch {
            print("[CaptureViewModel] Failed to activate AudioSession")
        }
        audioSession.addObserver(self, forKeyPath: "outputVolume", options: NSKeyValueObservingOptions.new, context: nil)
    }

    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "outputVolume" {
            if (self.isCapturing) {
                self.stopCapturing()
            } else {
                self.startCapturing()
            }
        }
    }
    
    //Start capturing
    func startCapturing() {
        
//        self.patternIndex = -1
        
        self.isCapturing = true
    }
    
    //Stop capturing
    func stopCapturing() {
        self.isCapturing = false
    }
    
    
}

extension CaptureViewModel : AVCaptureDataOutputSynchronizerDelegate {
    //Provides a collection of synchronized capture data to the delegate.
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        guard
            let synchronizedVideoData = synchronizedDataCollection.synchronizedData(for: self.cameraManager.frontTrueDepthCameraVideoOutput) as? AVCaptureSynchronizedSampleBufferData,
            !synchronizedVideoData.sampleBufferWasDropped
        else {
            return
        }
        //print(self.cameraManager.frontTrueDepthCameraInput.device.deviceWhiteBalanceGains)
        //Display
        //        var cgImage : CGImage!
        //        print("**************")
        //        print(self.cameraManager.frontTrueDepthCameraInput.device.exposureDuration)
        //        VTCreateCGImageFromCVPixelBuffer(synchronizedVideoData.sampleBuffer.imageBuffer!, options: nil, imageOut: &cgImage)
        //        let ciImage = CIImage(cgImage: cgImage)
        //        let uiImage = UIImage(ciImage: ciImage)
        //        //let  uiImage=getGammaCorrectedImage(sourceImage:cgImage)
        //
        //
        //
        //        DispatchQueue.main.async {
        //            self.viewModel.capturedPhoto = uiImage
        //        }
        //        self.imageSender.set(imageToBeSent: uiImage.resized(newWidth: 120))
        if self.isCapturing {
            var cgImage : CGImage!
            print("**************")
            print(self.cameraManager.frontTrueDepthCameraInput.device.exposureDuration)
            print(self.cameraManager.frontTrueDepthCameraInput.device.activeColorSpace)
            print(self.cameraManager.frontTrueDepthCameraInput.device.activeFormat)
            print(self.cameraManager.frontTrueDepthCameraInput.device.exposureMode.rawValue)
            print(self.cameraManager.frontTrueDepthCameraInput.device.exposureTargetBias)
            print(self.cameraManager.frontTrueDepthCameraInput.device.exposureTargetOffset)
            print(self.cameraManager.frontTrueDepthCameraInput.device.exposurePointOfInterest)
            print(self.cameraManager.frontTrueDepthCameraInput.device.isAdjustingExposure)
            
            
            let duration = self.cameraManager.frontTrueDepthCameraInput.device.exposureDuration
            let exposure_second = Float(duration.value) / Float(duration.timescale)
            exposuretimes.append(exposure_second)
            VTCreateCGImageFromCVPixelBuffer(synchronizedVideoData.sampleBuffer.imageBuffer!, options: nil, imageOut: &cgImage)
            let ciImage = CIImage(cgImage: cgImage)
            let uiImage = UIImage(ciImage: ciImage)
            //let  uiImage=getGammaCorrectedImage(sourceImage:cgImage)
            
            
            
            DispatchQueue.main.async {
                self.viewModel.capturedPhoto = uiImage
            }
            //self.imageSender.set(imageToBeSent: uiImage.resized(newWidth: 120))
            if !self.parameterSaved {
                self.parameterSaved = true
            }
            _ = self.diskWriter.addFrame(FrameInfo(colorFrame: uiImage, frameIndex: self.frameIndex, frameTime: CMTimeGetSeconds(synchronizedVideoData.timestamp)))
            self.frameIndex += 1
            DispatchQueue.main.async {
                self.viewModel.PhotoNubmerAdd()
            }
            //self.stopCapturing()
//            if(self.frameIndex%10 != 0){
//                DispatchQueue.main.asyncAfter(deadline: .now()+0.6)
//                {
//                    self.startCapturing()
//                }
//            }
            print(self.frameIndex)
            if self.frameIndex % 100 == 0 {
                self.stopCapturing()
            }
            
            
            
            
//            //add exposuretime to the end and record exposure
//                if(self.cameraManager.Canaddexposuretime()){
//                    DispatchQueue.main.async {
//                        self.cameraManager.Addexposuretime()
//                    }
//                    DispatchQueue.main.asyncAfter(deadline:.now()+0.1){
//                        self.startCapturing()
//                    }
//                }
//                else{
//                    let filename=diskWriter.baseDir+"/exposuretime.txt"
//                    let filemanager=FileManager.default
//                    //let file=NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.documentDirectory, FileManager.SearchPathDomainMask.userDomainMask, true).first
//                    let file=diskWriter.baseDir
//                    let path=file+filename
//                    print("++++++++++")
//                    print(path)
//                    filemanager.createFile(atPath: path, contents: nil,attributes: nil)
//                    let fileURL=try!FileManager.default.url(for:.documentDirectory,in:.userDomainMask,appropriateFor:  nil,create:false).appendingPathComponent("exposuretime.txt")
//                    (exposuretimes as NSArray).write(to: fileURL,atomically: true)
//
//                }
        }
    }
}


