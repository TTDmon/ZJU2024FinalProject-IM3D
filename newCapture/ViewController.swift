//
//  ViewController.swift
//  newCapture
//
//  Created by brdf on 2023/4/25.
//

import UIKit
import AVFoundation
import Accelerate.vImage
import VideoToolbox
class ViewController: UIViewController,AVCaptureVideoDataOutputSampleBufferDelegate{
    let player = AVPlayer()
    
    @IBOutlet weak var Begin: UIButton!
    @IBOutlet weak var playerView: PlayerView!
    var cgImageFormat = vImage_CGImageFormat(
        bitsPerComponent: 8,
        bitsPerPixel: 32,
        colorSpace: nil,
        bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue),
        version: 0,
        decode: nil,
        renderingIntent: .defaultIntent)
    var converter:vImageConverter?
    var sourceBuffers = [vImage_Buffer]()
    var destinationBuffer = vImage_Buffer()
    
    let videoSession=AVCaptureSession()
    let sessionQueue = DispatchQueue(label: "CameraManager.sessionQueue")
    var baseDir:String?
    let ciContext = CIContext()
    var diskwriter:DiskWriter?
    var imgnumber=0
    var iscapturing=false
    
    override var prefersStatusBarHidden: Bool{
        return true
    }
    override func viewDidLoad() {
        print("viewDidload")
        super.viewDidLoad()
        //load video
        guard let movieURL =
            Bundle.main.url(forResource: "test", withExtension: "avi") else {
                return
        }
        // Create an asset instance to represent the media file.
        let asset = AVURLAsset(url: movieURL)
        self.playerView.player = self.player
        self.player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        
        //configure camera
        configureSession()
        sessionQueue.async {
            self.videoSession.startRunning()
        }
        let current_time=getCurrentTime()
        self.baseDir="\(NSHomeDirectory())/Documents/\(current_time)/"
        self.diskwriter=DiskWriter(baseDir:self.baseDir!)
        self.diskwriter!.startDump()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        print("viewWillAppear")
    }

    override func viewWillDisappear(_ animated: Bool) {
        
        super.viewWillDisappear(animated)
    }
    
    @IBAction func startrecording(_ sender: UIButton) {
        print("startRecording")
        Begin.isHidden=true
        Begin.isEnabled=false
        print(Date().milliStamp)
        DispatchQueue.main.asyncAfter(deadline: .now()+5){
            self.iscapturing=true
            self.player.play()
        }
        self.sessionQueue.asyncAfter(deadline: .now()+130){
            self.iscapturing=false
        }
    }
    func configureSession(){
        print("begin confiuresession")
        self.videoSession.beginConfiguration()
        defer {
            self.videoSession.commitConfiguration()
        }
        
        //Find the camera
        guard let frontTrueDepthCamera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            print("can't configure camera")
            return
        }
        
        //Create And Add input
        do {
            let captureInput = try AVCaptureDeviceInput(device: frontTrueDepthCamera)
            self.videoSession.addInput(captureInput)
        }catch{
            print("can't create AVCaptureDeviceInput")
            return
        }

        
        //Create And Add video output
        let videoOutput=AVCaptureVideoDataOutput()
        let dataOutputQueue = DispatchQueue(label: "video data queue",
                                            qos: .userInitiated,
                                            attributes: [],
                                            autoreleaseFrequency: .workItem)
        
        videoOutput.setSampleBufferDelegate(self,
                                            queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        if videoSession.canAddOutput(videoOutput) {
            videoSession.addOutput(videoOutput)
        }
        guard let videoDataConnection = videoOutput.connection(with: .video) else {
            print("can't get connection")
            return
        }
        videoDataConnection.isEnabled = true
        videoDataConnection.videoOrientation = .portrait
        
        //Lock for configuration
        do {
            //Lock device
            try frontTrueDepthCamera.lockForConfiguration()
            frontTrueDepthCamera.setExposureModeCustom(duration: CMTime(value:10, timescale: 1000), iso: 18) { cmTime in
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
            frontTrueDepthCamera.activeVideoMaxFrameDuration=CMTime(value: 1, timescale: 30)
            frontTrueDepthCamera.activeVideoMinFrameDuration=CMTime(value:1,timescale: 30)
            frontTrueDepthCamera.unlockForConfiguration()
        }
        catch {
            print("can't configure camera")
            return
        }
        print("successfully cofigure session")
    }
    //get information from camera
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        print("capture:\(Date().milliStamp)")
        if(!self.iscapturing){
            return
        }
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer,
                                     CVPixelBufferLockFlags.readOnly)
        
        //storeImgFromPixelBuffer(pixelBuffer:pixelBuffer)
        var cgImage:CGImage?
        VTCreateCGImageFromCVPixelBuffer(pixelBuffer, options: nil, imageOut: &cgImage)
        let ciImage = CIImage(cgImage: cgImage!)
        let uiImage = UIImage(ciImage: ciImage)
        self.diskwriter!.addFrame(FrameInfo(colorFrame: uiImage, frameIndex: self.imgnumber))
        self.imgnumber+=1
        CVPixelBufferUnlockBaseAddress(pixelBuffer,
                                       CVPixelBufferLockFlags.readOnly)
        print("finish:\(Date().milliStamp)")
    }
    
    func storeImgFromPixelBuffer(pixelBuffer:CVPixelBuffer){
        print("test1")
        var error = kvImageNoError
        
        if converter == nil {
            let cvImageFormat = vImageCVImageFormat_CreateWithCVPixelBuffer(pixelBuffer).takeRetainedValue()
            
            vImageCVImageFormat_SetColorSpace(cvImageFormat,
                                              CGColorSpaceCreateDeviceRGB())
            
            vImageCVImageFormat_SetChromaSiting(cvImageFormat,
                                                kCVImageBufferChromaLocation_Center)
            
            guard
                let unmanagedConverter = vImageConverter_CreateForCVToCGImageFormat(
                    cvImageFormat,
                    &cgImageFormat,
                    nil,
                    vImage_Flags(kvImagePrintDiagnosticsToConsole),
                    &error),
                error == kvImageNoError else {
                    print("vImageConverter_CreateForCVToCGImageFormat error:", error)
                    return
            }
            
            converter = unmanagedConverter.takeRetainedValue()
        }
        
        if sourceBuffers.isEmpty {
            let numberOfSourceBuffers = Int(vImageConverter_GetNumberOfSourceBuffers(converter!))
            sourceBuffers = [vImage_Buffer](repeating: vImage_Buffer(),
                                            count: numberOfSourceBuffers)
        }
        
        error = vImageBuffer_InitForCopyFromCVPixelBuffer(
            &sourceBuffers,
            converter!,
            pixelBuffer,
            vImage_Flags(kvImageNoAllocate))
        
        guard error == kvImageNoError else {
            return
        }
        
        
        if destinationBuffer.data == nil {
            error = vImageBuffer_Init(&destinationBuffer,
                                      UInt(CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)),
                                      UInt(CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)),
                                      cgImageFormat.bitsPerPixel,
                                      vImage_Flags(kvImageNoFlags))
            
            guard error == kvImageNoError else {
                return
            }
        }
        
        error = vImageConvert_AnyToAny(converter!,
                                       &sourceBuffers,
                                       &destinationBuffer,
                                       nil,
                                       vImage_Flags(kvImageNoFlags))
        
        guard error == kvImageNoError else {
            return
        }
        
//        error = vImageEqualization_ARGB8888(&destinationBuffer,
//                                            &destinationBuffer,
//                                            vImage_Flags(kvImageLeaveAlphaUnchanged))
//
//        guard error == kvImageNoError else {
//            return
//        }
        
        let cgImage = vImageCreateCGImageFromBuffer(
            &destinationBuffer,
            &cgImageFormat,
            nil,
            nil,
            vImage_Flags(kvImageNoFlags),
            &error)
        print("test2")
        if let cgImage = cgImage, error == kvImageNoError {
            let ciimage=CIImage(cgImage: cgImage.takeRetainedValue())
            do{
                try self.ciContext.writePNGRepresentation(of: ciimage, to:URL(fileURLWithPath: "\(String(describing: self.baseDir))\(self.imgnumber).png"), format:  .RGBA8, colorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!)
            }
            catch{
                return
            }
        }
    }
}

