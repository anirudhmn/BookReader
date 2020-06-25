//
//  RemoteViewController.swift
//  Reader
//
//  Created by Anirudh Natarajan on 6/25/20.
//  Copyright © 2020 Anirudh Natarajan. All rights reserved.
//

import Foundation
import UIKit
import Firebase

class RemoteViewController: UIViewController {
    
    var epubName = String()
    var doubleL = false
    var doubleR = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        rightSwipe.direction = .right
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        leftSwipe.direction = .left
        
        view.addGestureRecognizer(rightSwipe)
        view.addGestureRecognizer(leftSwipe)
    }
    
    @objc func handleSwipe(sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            switch sender.direction {
            case .right:
                let ref = Database.database().reference(fromURL: "URL").child(epubName)
                
                var swipe = "left"
                if doubleL {
                    swipe = "left_"
                    doubleL = false
                } else {
                    doubleL = true
                }
                
                let v = ["flip":swipe]
                ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                    if err != nil {
                        print(err)
                        return
                    }
                })
            case .left:
                let ref = Database.database().reference(fromURL: "URL").child(epubName)
                
                var swipe = "right"
                if doubleR {
                    swipe = "right_"
                    doubleR = false
                } else {
                    doubleR = true
                }
                
                let v = ["flip":swipe]
                ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                    if err != nil {
                        print(err)
                        return
                    }
                })
            default:
                break
            }
        }
    }
}
