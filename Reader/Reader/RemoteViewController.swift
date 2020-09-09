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

class RemoteViewController: UIViewController, UISearchBarDelegate {
    
    @IBOutlet var currentPageField: UITextField!
    @IBOutlet var searchField: UISearchBar!
    @IBOutlet var searchResultsField: UITextView!
    
    
    var bookName = String()
    var ref = DatabaseReference()
    var currentPage = 0
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        searchField.delegate = self
        searchResultsField.text = ""
        searchResultsField.isHidden = true
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        rightSwipe.direction = .right
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        leftSwipe.direction = .left
        
        view.addGestureRecognizer(rightSwipe)
        view.addGestureRecognizer(leftSwipe)
        
        ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(bookName)
        
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            for child in snapshot.children {
                let snap = child as! DataSnapshot
                let key = snap.key
                if key == "current" {
                    self.currentPage = Int("\(snap.value ?? 0)")!
                    self.currentPageField.text = "\(self.currentPage+1)"
                }
            }
        })
        
        ref.observe(.childChanged) { (snapshot) in
            if snapshot.key == "current" {
                self.currentPage = Int("\(snapshot.value ?? 0)")!
                self.currentPageField.text = "\(self.currentPage+1)"
            } else if snapshot.key == "searchResults" {
                self.updateSearch()
            }
        }
        
        self.addDoneButtonOnKeyboard()
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        view.addGestureRecognizer(tap)
    }
            
    @objc func dismissKeyboard() {
        currentPageField.text = "\(currentPage+1)"
        view.endEditing(true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchBar.text != "" {
            var v = ["search":""]
            ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
            })
            v = ["search":searchBar.text!]
            ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
            })
        }
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchText == "" {
            searchResultsField.isHidden = true
            dismissKeyboard()
        }
    }
    
    func updateSearch() {
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            for child in snapshot.children {
                let snap = child as! DataSnapshot
                let key = snap.key
                if key == "searchResults" {
                    self.searchResultsField.text = "\(snap.value ?? "")"
                    self.searchResultsField.isHidden = false
                }
            }
        })
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
            let v = ["current":"\(currentPage-1)", "update":"page"]
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
