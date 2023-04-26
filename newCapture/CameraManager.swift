//
//  CameraManager.swift
//  IOSCapture
//
//  Created by YJJ on 2022/7/17.
//

import AVFoundation
import Foundation

class CameraManager {
    
    //Camera status
    enum Status {
        case unConfigured
        case unAuthorized
        case configureFailed
        case configured
    }
    private var status : Status = .unConfigured
    var exposuretime:CMTimeValue=1
    
    //Camera errors
    private(set) var error: CameraError?
    
    //Capture session
    private let videoSession = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "CameraManager.sessionQueue")
    
    //Data input and output
    private(set) var frontTrueDepthCameraInput : AVCaptureDeviceInput!
    let frontTrueDepthCameraVideoOutput = AVCaptureVideoDataOutput()
    private var frontTrueDepthCameraOutputSynchronizer: AVCaptureDataOutputSynchronizer!
    
    private let outputQueue = DispatchQueue(label: "CameraManager.outputQueue")
    
    init() {
        print("CameraManager_init")
        //Firstly check permissions
        self.checkPermissions()
        //Then configure cameras
        self.sessionQueue.async {
            self.configureCaptureSession()
        }
        print("CameraManager_init done")
    }
    func Canaddexposuretime()->Bool{
        if(exposuretime<100){
            return true
        }
        else{
            return false}
    }
    func Addexposuretime(){
        print("--------------------")
        if(exposuretime<100){
            exposuretime+=1
            status = .unConfigured
        
            guard let frontTrueDepthCamera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
                self.status = .configureFailed
                self.error = .cameraUnavailable("Front True Depth Camera")
                return
            }
            do{
                try frontTrueDepthCamera.lockForConfiguration()
                frontTrueDepthCamera.setExposureModeCustom(duration: CMTime(value: self.exposuretime, timescale: 2000), iso: 18) { cmTime in
                //frontTrueDepthCamera.setExposureModeCustom(duration: frontTrueDepthCamera.activeFormat.maxExposureDuration, iso: 18) { cmTime in
                    print("Finish configure exposure")
                    print(frontTrueDepthCamera.exposureDuration)
                    print(frontTrueDepthCamera.iso)
                }
                //frontTrueDepthCamera.unlockForConfiguration()
                return
                
            }
            catch{
                self.status = .configureFailed
                self.error = .cannotLockCamera("Front True Depth Camera")
                return
            }
            
        }
        return
        
    }
    
    func startVideoSession(delegate : AVCaptureDataOutputSynchronizerDelegate? = nil, completedHandler : (() -> Void)? = nil) {
        self.sessionQueue.async {
            if !self.videoSession.isRunning {
                print("[CameraManager] Start video session")
                if let delegate = delegate {
                    self.frontTrueDepthCameraOutputSynchronizer.setDelegate(delegate, queue: self.outputQueue)
                }
                self.videoSession.startRunning()
            }
            if let completedHandler = completedHandler {
                completedHandler()
            }
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
            self.frontTrueDepthCameraInput = try AVCaptureDeviceInput(device: frontTrueDepthCamera)
        }
        catch {
            self.status = .configureFailed
            self.error = .cannotCreateCaptureInput(error)
            return false
        }
        
        //Add input
        guard self.videoSession.canAddInput(self.frontTrueDepthCameraInput) else {
            self.status = .configureFailed
            self.error = .cannotAddInput("Front True Depth Camera")
            return false
        }
        self.videoSession.addInput(self.frontTrueDepthCameraInput)
        
        //Add video output
        guard videoSession.canAddOutput(self.frontTrueDepthCameraVideoOutput) else {
            self.status = .configureFailed
            self.error = .cannotAddOutput("Front True Depth Camera Video Data")
            return false
        }
        videoSession.addOutput(self.frontTrueDepthCameraVideoOutput)
        self.frontTrueDepthCameraVideoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        //self.frontTrueDepthCameraVideoOutput.videoSettings = [:]
        guard let videoDataConnection = frontTrueDepthCameraVideoOutput.connection(with: .video) else {
            self.status = .configureFailed
            self.error = .cannotFindConnection("Front True Depth Camera Video Data")
            return false
        }
        videoDataConnection.isEnabled = true
        videoDataConnection.videoOrientation = .portrait
        
        //Add depth output

//        guard let format=frontTrueDepthCamera.formats.first(where: {$0.isVideoHDRSupported})else{
//            fatalError("no suitable format")
//        }
//        for format in frontTrueDepthCamera.formats{
//            print(format)
//
//        }
        //change format to best quality
//        let format=frontTrueDepthCamera.formats.last!
//        print(format)
        
        //Lock for configuration
        do {
            //Lock device
            try frontTrueDepthCamera.lockForConfiguration()
            //Configure exposure
//          frontTrueDepthCamera.activeFormat=format
            print(frontTrueDepthCamera.isExposureModeSupported(.autoExpose))
            print(frontTrueDepthCamera.isExposureModeSupported(.continuousAutoExposure))
            print(frontTrueDepthCamera.isExposureModeSupported(.custom))
            print(frontTrueDepthCamera.isExposureModeSupported(.locked))
            //frontTrueDepthCamera.exposureMode = .autoExpose
            print("minISO:\(frontTrueDepthCamera.activeFormat.minISO)")
            print("maxISO:\(frontTrueDepthCamera.activeFormat.maxISO)")
            print("minExposure\(frontTrueDepthCamera.activeFormat.minExposureDuration)")
            print("maxExposure\(frontTrueDepthCamera.activeFormat.maxExposureDuration)")
            frontTrueDepthCamera.setExposureModeCustom(duration: CMTime(value:1 , timescale: 2000), iso: 18) { cmTime in
            //frontTrueDepthCamera.setExposureModeCustom(duration: frontTrueDepthCamera.activeFormat.maxExposureDuration, iso: 18) { cmTime in
                print("Finish configure exposure")
                print(frontTrueDepthCamera.exposureDuration)
                print(frontTrueDepthCamera.iso)
            }
            //Configure focus
            //frontTrueDepthCamera.setFocusModeLocked(lensPosition: <#T##Float#>)
            //frontTrueDepthCamera.focusMode = .locked
            //print(frontTrueDepthCamera.focusMode.rawValue)
            print("Focus:")
            print(frontTrueDepthCamera.isAdjustingFocus)
            print(frontTrueDepthCamera.focusMode.rawValue)
            print(frontTrueDepthCamera.focusPointOfInterest)
            print(frontTrueDepthCamera.isFocusModeSupported(.autoFocus))
            print(frontTrueDepthCamera.isFocusModeSupported(.continuousAutoFocus))
            print(frontTrueDepthCamera.isFocusModeSupported(.locked))
            //Configure white
            frontTrueDepthCamera.setWhiteBalanceModeLocked(with: .init(redGain: 2.2, greenGain: 1.0, blueGain: 1.8)) { cmTimer in
            //frontTrueDepthCamera.setWhiteBalanceModeLocked(with: .init(redGain: 1.0, greenGain: 1.0, blueGain: 1.0)) { cmTimer in
                print("Finish configure white balance")
                print(frontTrueDepthCamera.deviceWhiteBalanceGains)
            }
            //frontTrueDepthCamera.whiteBalanceMode = .autoWhiteBalance
            //frontTrueDepthCamera.whiteBalanceMode = .locked
            //print(frontTrueDepthCamera.whiteBalanceMode.rawValue)
            //frontTrueDepthCamera.whiteBalanceMode = .continuousAutoWhiteBalance
            print(frontTrueDepthCamera.isWhiteBalanceModeSupported(.autoWhiteBalance))
            print(frontTrueDepthCamera.isWhiteBalanceModeSupported(.continuousAutoWhiteBalance))
            print(frontTrueDepthCamera.isWhiteBalanceModeSupported(.locked))
            //Configure HDR
            frontTrueDepthCamera.automaticallyAdjustsVideoHDREnabled = false
            //frontTrueDepthCamera.isVideoHDREnabled = false
            frontTrueDepthCamera.automaticallyAdjustsFaceDrivenAutoExposureEnabled=false
            //Unlock device
            //frontTrueDepthCamera.unlockForConfiguration()
        }
        catch {
            self.status = .configureFailed
            self.error = .cannotLockCamera("Front True Depth Camera")
            return false
        }
        
        //Use an AVCaptureDataOutputSynchronizer
        //to synchronize the video data and depth data outputs.
        self.frontTrueDepthCameraOutputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [self.frontTrueDepthCameraVideoOutput])

        //Finish configure
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


