//
//  ViewController.swift
//  LogExperiment
//
//  Created by Zachary Waldowski on 9/7/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
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
        Log.ui.show("Next, a scalar: \(rect.minX)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Activity.label("stuff") {
            Log.processing.show("Doing some work...")

            Activity.label("more stuff") {
                Log.processing.error("Things are going bad down here, cap'n!")
            }
        }
    }

}
