//
//  ViewController.swift
//  LogExperiment
//
//  Created by Zachary Waldowski on 9/7/16.
//  Copyright © 2016 Big Nerd Ranch. All rights reserved.
//

import UIKit
import Loggy

class ViewController: UIViewController {

    enum Log: LogSubsystem {
        case processing, ui, actions
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let text = "Xcode"
        Log.ui.debug("This will only show in Xcode! Hello, \(text)!")

        let rect = CGRect(x: 1.5, y: 2, width: 3, height: 4)
        Log.ui.show("Hello, scalar. \(rect.minX)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Activity(label: "stuff").active {
            Log.processing.show("Doing some work...")

            Activity(label: "more stuff").active {
                Log.processing.error("Things are going bad down here, cap'n!")
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}
