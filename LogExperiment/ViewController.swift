//
//  ViewController.swift
//  LogExperiment
//
//  Created by Zachary Waldowski on 9/7/16.
//  Copyright © 2016-2018 Big Nerd Ranch. Licensed under MIT.
//

import UIKit
import Loggy

let uiLog = OSLog(subsystem: "com.bignerdranch.LogExperiment", category: "ViewController.UI")
let processingLog = OSLog(subsystem: "com.bignerdranch.LogExperiment", category: "ViewController.Processing")

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        let text = "Xcode"
        uiLog.debug("This will only show in Xcode! Hello, \(text)!")

        let rect = CGRect(x: 1.5, y: 2, width: 3, height: 4)
        uiLog.show("Next, a scalar: \(rect.minX)")
        uiLog.show("Now, more complex: \(rect)")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        Activity.label("stuff") {
            processingLog.show("Doing some work...")

            Activity.label("more stuff") {
                processingLog.error("Things are going bad down here, cap'n!")
            }
        }
    }

}
