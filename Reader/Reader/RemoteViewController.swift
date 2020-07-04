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
    
    @IBOutlet var currentPageField: UITextField!
    
    var epubName = String()
    var ref = DatabaseReference()
    var currentPage = 0
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        rightSwipe.direction = .right
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        leftSwipe.direction = .left
        
        view.addGestureRecognizer(rightSwipe)
        view.addGestureRecognizer(leftSwipe)
        ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(epubName)
        
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            for child in snapshot.children {
                let snap = child as! DataSnapshot
                let key = snap.key
                if key == "current" {
                    self.currentPage = Int("\(snap.value ?? 0)")!
                    self.currentPageField.text = "\(self.currentPage)"
                }
            }
        })
        
        ref.observe(.childChanged) { (snapshot) in
            if snapshot.key == "current" {
                self.currentPage = Int("\(snapshot.value ?? 0)")!
                self.currentPageField.text = "\(self.currentPage)"
            }
        }
        
        self.addDoneButtonOnKeyboard()
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
            
    @objc func dismissKeyboard() {
        currentPageField.text = "\(currentPage)"
        view.endEditing(true)
    }
    
    @objc func handleSwipe(sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            switch sender.direction {
            case .right:
                let v = ["update":"previous"]
                ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                    if err != nil {
                        print(err)
                        return
                    }
                })
            case .left:
                let v = ["update":"next"]
                ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                    if err != nil {
                        print(err)
                        return
                    }
                })
            default:
                break
            }
            
            let v = ["update":"none"]
            ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
            })
        }
    }
    
    func addDoneButtonOnKeyboard() {
        let doneToolbar: UIToolbar = UIToolbar(frame: CGRect.init(x: 0, y: 0, width: 320, height: 50))
        doneToolbar.barStyle = UIBarStyle.default

        let flexSpace = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)
        let done: UIBarButtonItem = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.done, target: self, action: #selector(doneButtonAction))

        var items = [UIBarButtonItem]()
        items.append(flexSpace)
        items.append(done)

        doneToolbar.items = items
        doneToolbar.sizeToFit()

        self.currentPageField.inputAccessoryView = doneToolbar
    }
    
    @objc func doneButtonAction() {
        if currentPageField.text != "" {
            currentPage = Int(currentPageField.text!) ?? 0
            let v = ["current":"\(currentPage)", "update":"page"]
            ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
            })
            view.endEditing(true)
        }
        
        let v = ["update":"none"]
        ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
            if err != nil {
                print(err)
                return
            }
        })
    }
}
