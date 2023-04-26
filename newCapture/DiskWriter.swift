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
    let frameTime : Double
}

class DiskWriter {
    
    static let ciContext = CIContext()
    static let colorSpace = CGColorSpace(name: CGColorSpace.linearSRGB)!
    
    //Settings
    private(set) var baseDir : String
    private(set) var photoDir : String
    //private(set) var videoFileName : String
    private(set) var videoFPS : Double
    private(set) var videoWidth : Int
    private(set) var videoHeight : Int
    
    //Constructor
    init(baseDir : String, photoDir : String,  videoFPS : Double, videoWidth : Int, videoHeight : Int) {
        self.baseDir = "\(NSHomeDirectory())/Documents/\(baseDir)/"
        //self.baseDir=baseDir
        self.photoDir = photoDir
        self.videoFPS = videoFPS
        self.videoWidth = videoWidth
        self.videoHeight = videoHeight
        //Create the directory to write
        try! FileManager.default.createDirectory(atPath: self.baseDir, withIntermediateDirectories: true, attributes: nil)
        try! FileManager.default.createDirectory(atPath: self.baseDir+self.photoDir, withIntermediateDirectories: true, attributes: nil)
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
    func addFrame(_ frame : FrameInfo) -> Bool {
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
                    try! DiskWriter.ciContext.writePNGRepresentation(of: frame.colorFrame.ciImage!, to: URL(fileURLWithPath: "\(self.baseDir)\(self.photoDir)/\(frame.frameIndex).png"), format: .RGBA8, colorSpace:DiskWriter.colorSpace)
                    
                    print("[DiskWriter] Write \(frame.frameIndex).png")
                    print(self.baseDir)
                }
            }
            print("[DiskWriter] Finish dumping frames")
            self.isDumping = false
        }
    }
    
    //Stop dump
    func stopDump() {
        self.shouldStopDumping = true
    }
}


