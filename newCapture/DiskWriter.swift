//
//  DiskWriter.swift
//  IOSCapture
//
//  Created by YJJ on 2022/7/31.
//

import Foundation
import Atomics
import simd
import CoreMotion
import CoreServices
import UIKit
//The source information of a frame
struct FrameInfo {
    let colorFrame : UIImage
    let frameIndex : Int
}

class DiskWriter {
    
    static let ciContext = CIContext()
    static let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
    
    //Settings
    private(set) var baseDir : String
    
    //Constructor
    init(baseDir : String) {
        self.baseDir = baseDir
        //Create the directory to write
        try! FileManager.default.createDirectory(atPath: self.baseDir, withIntermediateDirectories: true, attributes: nil)

    }
    
    private let frameQueue = ConcurrentQueue<FrameInfo>()
    
    private let dispatchQueue = DispatchQueue(label: "DiskWriter", qos: .userInitiated, attributes: .concurrent)
    
    private var _isDumping = ManagedAtomic<Bool>(false)
    private(set) var isDumping : Bool {
        set {
            self._isDumping.store(newValue, ordering: .relaxed)
        }
        get {
            return self._isDumping.load(ordering: .relaxed)
        }
    }
    
    private var _shouldStopDumping = ManagedAtomic<Bool>(false)
    private(set) var shouldStopDumping : Bool {
        set {
            self._shouldStopDumping.store(newValue, ordering: .relaxed)
        }
        get {
            return self._shouldStopDumping.load(ordering: .relaxed)
        }
    }
    
    
    //Add frame
    func addFrame(_ frame : FrameInfo)->Bool {
         return self.frameQueue.enqueue(frame)
    }
    //Start dump
    func startDump() {
        self.isDumping = true
        self.shouldStopDumping = false
        
        self.dispatchQueue.async {
            print("[DiskWriter] Start dumping frames")
            //Continue to dump until self.isDumping == false
            while !self.shouldStopDumping {
                while let frame = self.frameQueue.dequeue() {
                    if(frame.frameIndex>=4&&frame.frameIndex<=3600&&frame.frameIndex%3==1){
                        self.dispatchQueue.async {
                            try! DiskWriter.ciContext.writePNGRepresentation(of: frame.colorFrame.ciImage!, to: URL(fileURLWithPath: "\(self.baseDir)/\(frame.frameIndex/3).png"), format: .RGBA8, colorSpace:DiskWriter.colorSpace)
                            print("[DiskWriter] Write \(frame.frameIndex/3).png")
                        }
                    }
                }
            }
            //Finish dump
//            videoWriter.close()
            print("[DiskWriter] Finish dumping frames")
            self.isDumping = false
        }
    }
    
    //Stop dump
    func stopDump() {
        self.shouldStopDumping = true
    }
}
