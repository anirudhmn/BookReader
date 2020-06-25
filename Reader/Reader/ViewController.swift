//
//  ViewController.swift
//  Reader
//
//  Created by Anirudh Natarajan on 6/24/20.
//  Copyright © 2020 Anirudh Natarajan. All rights reserved.
//

import UIKit
import Foundation
import EpubExtractor
import Firebase

class ViewController: UIViewController {
    var epubs = [("Books",[""])]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let fm = FileManager.default
        let path = Bundle.main.resourcePath!

        do {
            let items = try fm.contentsOfDirectory(atPath: path)

            for item in items {
                if item.contains("epub") {
                    if self.epubs[0].1[0]=="" {
                        self.epubs[0].1[0] = String(item.split(separator: ".")[0])
                    } else {
                        self.epubs[0].1.append(String(item.split(separator: ".")[0]))
                    }
                }
            }
        } catch {
            print(error)
        }
                        
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.epubs.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.epubs[section].1.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "identifier")
        
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "identifier")
        }
        
        cell?.textLabel?.text = self.epubs[indexPath.section].1[indexPath.item]
        
        return cell!
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.epubs[section].0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if book {
            let detailVC = self.storyboard?.instantiateViewController(withIdentifier: "DetailVC") as! EpubDetailViewController
            detailVC.epubName = self.epubs[indexPath.section].1[indexPath.item]
            
            let ref = Database.database().reference(fromURL: "URL").child(detailVC.epubName!)
            var first = true
            ref.observeSingleEvent(of: .value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    let key = snap.key
                    if key == "current" {
                        first = false
                    }
                }
                
                if first {
                    let v = ["page":"0", "section":"0", "current":"0", "flip":"none"]
                    ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                        if err != nil {
                            print(err)
                            return
                        }
                    })
                }
            })
            
            self.navigationController?.show(detailVC, sender: self)
        } else {
            let remoteVC = self.storyboard?.instantiateViewController(withIdentifier: "RemoteVC") as! RemoteViewController
            remoteVC.epubName = self.epubs[indexPath.section].1[indexPath.item]
            self.navigationController?.show(remoteVC, sender: self)
        }
    }
}

