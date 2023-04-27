//
//  ViewController.swift
//  newCapture
//
//  Created by brdf on 2023/4/25.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {
    let player = AVPlayer()
    
    @IBOutlet weak var Begin: UIButton!
    @IBOutlet weak var playerView: PlayerView!
    var cameramanager:CameraManager!
    override func viewDidLoad() {
        print("viewDidload")
        cameramanager=CameraManager(viewcontroller:self)
        super.viewDidLoad()
        guard let movieURL =
            Bundle.main.url(forResource: "out_9.99", withExtension: "avi") else {
                return
        }
        // Create an asset instance to represent the media file.
        let asset = AVURLAsset(url: movieURL)
        self.playerView.player = self.player
        self.player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        
        // Do any additional setup after loading the view.
    }
    override func viewWillAppear(_ animated: Bool) {
        print("viewWillAppear")
        print(Date().milliStamp)
    }

    override func viewWillDisappear(_ animated: Bool) {
        self.cameramanager.stopRecordingMovie()
        super.viewWillDisappear(animated)
    }
    @IBAction func startrecording(_ sender: UIButton) {
        Begin.isHidden=true
        Begin.isEnabled=false
        print(Date().milliStamp)
//        DispatchQueue.main.asyncAfter(deadline: .now()+0.075){
//            self.player.play()
//        }
        print(Date().milliStamp)
        DispatchQueue.main.asyncAfter(deadline:.now()+3){
            self.cameramanager.startRecordingMovie()
        }
    }
    
//    @IBAction func stopRecording(_ sender: Any) {
//        print("stopRecording")
//        self.cameramanager.stopRecordingMovie()
//    }

}

