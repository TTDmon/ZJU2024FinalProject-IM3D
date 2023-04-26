//
//  ViewController.swift
//  newCapture
//
//  Created by brdf on 2023/4/25.
//

import UIKit

class ViewController: UIViewController {
    var viewModel:ContentViewModel!

    override func viewDidLoad() {
        print("viewDidload")
        super.viewDidLoad()
        self.viewModel=ContentViewModel()
        // Do any additional setup after loading the view.
    }


}

