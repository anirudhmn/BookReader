//
//  InitialViewController.swift
//  Reader
//
//  Created by Anirudh Natarajan on 6/25/20.
//  Copyright © 2020 Anirudh Natarajan. All rights reserved.
//

import Foundation
import UIKit

var book = true

class InitialViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func bookPressed(_ sender: Any) {
        book = true
        self.performSegue(withIdentifier: "start", sender: self)
    }
    
    @IBAction func remotePressed(_ sender: Any) {
        book = false
        self.performSegue(withIdentifier: "start", sender: self)
    }
}
    
