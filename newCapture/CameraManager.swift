//
//  CameraManager.swift
//  IOSCapture
//
//  Created by YJJ on 2022/7/17.
//

import AVFoundation
import Foundation

class CameraManager :NSObject, ObservableObject,AVCaptureFileOutputRecordingDelegate{
    
    //Camera status
    enum Status {
        case unConfigured
        case unAuthorized
        case configureFailed
        case configured
    }
    unowned private var viewController:ViewController!
    private var status : Status = .unConfigured
    //Camera errors
    private(set) var error: CameraError?
    
    //Capture session
    private let videoSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "CameraManager.sessionQueue")
    //private let outputQueue = DispatchQueue(label: "CameraManager.outputQueue")
    
    //Data input and output
    private(set) var fileInput : AVCaptureDeviceInput!
    let movieFileOutput = AVCaptureMovieFileOutput()
    
    
    init(viewcontroller:ViewController) {
        print("CameraManager_init")
        super.init()
        self.viewController=viewcontroller
        //Firstly check permissions
        self.checkPermissions()
        //Then configure cameras
        self.sessionQueue.async {
            self.configureCaptureSession()
        }
        self.startVideoSession()
        print("CameraManager_init done")
    }
    
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL, from connections: [AVCaptureConnection], error: Error?) {
        return
    }
    func fileOutput(_ output: AVCaptureFileOutput, didStartRecordingTo fileURL: URL, from connections: [AVCaptureConnection]){
        print("didStartRecordingTo")
        print(Date().milliStamp)
            self.viewController.player.play()
        print(Date().milliStamp)
    }
    func startVideoSession() {
        self.sessionQueue.async {
            if !self.videoSession.isRunning {
                print("[CameraManager] Start video session")
                self.videoSession.startRunning()
            }
        }
    }
    func startRecordingMovie(){
        self.sessionQueue.async {
            let name=String(getCurrentTime())
            let path="\(NSHomeDirectory())/Documents/\(name).mov"
            let url=URL(fileURLWithPath: path)
            self.movieFileOutput.startRecording(to: url, recordingDelegate: self)
            
        }
    }
    func stopRecordingMovie(){
            if(movieFileOutput.isRecording){
                print("stoprecording")
                movieFileOutput.stopRecording()
            }
    }
       
    func stopVideoSession(completedHandler : (() -> Void)? = nil) {
        self.sessionQueue.async {
            if self.videoSession.isRunning {
                print("[CameraManager] Stop video session")
                self.videoSession.stopRunning()
            }
            if let completedHandler = completedHandler {
                completedHandler()
            }
        }
    }
    
    //Check permissions
    private func checkPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video) { authorized in
                if !authorized {
                    self.status = .unAuthorized
                    self.error = .deniedAuthorization
                }
                self.sessionQueue.resume()
            }
        case .restricted:
            self.status = .unAuthorized
            self.error = .restrictedAuthorization
        case .denied:
            self.status = .unAuthorized
            self.error = .deniedAuthorization
        case .authorized:
            break
        @unknown default:
            self.status = .unAuthorized
            self.error = .unknownAuthorization
        }
    }

    //Must be called on the session queue
    private func configureCaptureSession() {
        print("camera.ConfigureCaptureSession()")
        guard status == .unConfigured else {
            return
        }
        
        if self.configureFrontTrueDepthCameraForVideo() {
            self.status = .configured
            return
        }
        print("camera.ConfigureCaptureSession() done")
    }
    
    private func FindVideoFormatWithmaxexposuretime(device:AVCaptureDevice)->AVCaptureDevice.Format?
    { var selected_format=device.activeFormat
        var maxexposure=Double(device.activeFormat.maxExposureDuration.value) / Double(device.activeFormat.maxExposureDuration.timescale)
        for format in device.formats{
            let currentexposure = Double(format.maxExposureDuration.value) / Double(format.maxExposureDuration.timescale)
            if(currentexposure>maxexposure){
                maxexposure=currentexposure
                selected_format=format
                
            }
        }
        return selected_format
    }
    
    //Configure front true depth camera for photo
    func configureFrontTrueDepthCameraForVideo() -> Bool {
        self.videoSession.beginConfiguration()
        defer {
            self.videoSession.commitConfiguration()
        }
        
        //Find the camera
        guard let frontTrueDepthCamera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            self.status = .configureFailed
            self.error = .cameraUnavailable("Front True Depth Camera")
            return false
        }
        
        //Create input
        do {
            self.fileInput = try AVCaptureDeviceInput(device: frontTrueDepthCamera)
        }
        catch {
            self.status = .configureFailed
            self.error = .cannotCreateCaptureInput(error)
            return false
        }
        
        //Add input
        guard self.videoSession.canAddInput(self.fileInput) else {
            self.status = .configureFailed
            self.error = .cannotAddInput("Front True Depth Camera")
            return false
        }
        self.videoSession.addInput(self.fileInput)
        
        //Add video output
        guard videoSession.canAddOutput(self.movieFileOutput) else {
            self.status = .configureFailed
            self.error = .cannotAddOutput("Front True Depth Camera Video Data")
            return false
        }
        videoSession.addOutput(self.movieFileOutput)
        //self.movieFileOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        //self.frontTrueDepthCameraVideoOutput.videoSettings = [:]
        guard let videoDataConnection = movieFileOutput.connection(with: .video) else {
            self.status = .configureFailed
            self.error = .cannotFindConnection("Front True Depth Camera Video Data")
            return false
        }
        videoDataConnection.isEnabled = true
        videoDataConnection.videoOrientation = .portrait
        
        //Lock for configuration
        do {
            //Lock device
            try frontTrueDepthCamera.lockForConfiguration()
            frontTrueDepthCamera.setExposureModeCustom(duration: CMTime(value:1 , timescale: 20), iso: 18) { cmTime in
                print("Finish configure exposure")
                print(frontTrueDepthCamera.exposureDuration)
                print(frontTrueDepthCamera.iso)
            }
            frontTrueDepthCamera.setWhiteBalanceModeLocked(with: .init(redGain: 2.2, greenGain: 1.0, blueGain: 1.8)) { cmTimer in
                print("Finish configure white balance")
                print(frontTrueDepthCamera.deviceWhiteBalanceGains)
            }
            //Configure HDR
            frontTrueDepthCamera.automaticallyAdjustsVideoHDREnabled = false
            //frontTrueDepthCamera.isVideoHDREnabled = false
            frontTrueDepthCamera.automaticallyAdjustsFaceDrivenAutoExposureEnabled=false
            //Unlock device
            frontTrueDepthCamera.unlockForConfiguration()
        }
        catch {
            self.status = .configureFailed
            self.error = .cannotLockCamera("Front True Depth Camera")
            return false
        }
        
        return true
    }
}




enum CameraError: Error {
    //Check permissions
    case restrictedAuthorization
    case deniedAuthorization
    case unknownAuthorization
    //Configure
    case multiCamNotSupported
    case cameraUnavailable(String)
    case cannotLockCamera(String)
    case cannotCreateCaptureInput(Error)
    case cannotAddInput(String)
    case cannotFindPort(String)
    case cannotFindConnection(String)
    case cannotAddOutput(String)
    case cannotAddConnection(String)
}

extension CameraError: LocalizedError {
    var errorDescription: String? {
        switch self {
        //Check permissions
        case .restrictedAuthorization:
            return "Attempting to access a restricted capture device"
        case .deniedAuthorization:
            return "Camera access denied"
        case .unknownAuthorization:
            return "Unknown authorization status for capture device"
        //Configure
        case .multiCamNotSupported:
            return "Multiple camera captures not supported"
        case .cameraUnavailable(let camera):
            return "Camera unavailable: \(camera)"
        case .cannotLockCamera(let camera):
            return "Cannot lock camera for configuration: \(camera)"
        case .cannotCreateCaptureInput(let error):
            return "Cannot Creatin capture input for camera: \(error.localizedDescription)"
        case .cannotAddInput(let camera):
            return "Cannot add capture input to session: \(camera)"
        case .cannotFindPort(let camera):
            return "Cannot find camera port: \(camera)"
        case .cannotFindConnection(let camera):
            return "Cannot find connection: \(camera)"
        case .cannotAddOutput(let camera):
            return "Cannot add video output to session: \(camera)"
        case .cannotAddConnection(let camera):
            return "Cannot add connection to session: \(camera)"
        }
    }
}


