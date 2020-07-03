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
    
    @IBOutlet var tableView: UITableView!
    
    var epubs = [("Books",[""])]
    var refreshControl = UIRefreshControl()
    var book = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        #if targetEnvironment(macCatalyst)
            self.book = true
        #else
            self.book = false
        #endif
        
        tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if book {
            let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addBook))
            navigationItem.rightBarButtonItems = [addButton]
        }
        
        updateBooks()
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
    }
    
    func updateBooks() {
        epubs = [("Books",[""])]
        if book {
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
                for i in fileURLs {
                    if i.absoluteString.contains("epub") {
                        let a = i.absoluteString.split(separator: "/")
                        let b = a[a.count-1]
                        let c = b.replacingOccurrences(of: "%20", with: " ")
                        
                        if self.epubs[0].1[0]=="" {
                            self.epubs[0].1[0] = String(c.split(separator: ".")[0])
                        } else {
                            self.epubs[0].1.append(String(c.split(separator: ".")[0]))
                        }
                    }
                }
            } catch {
                print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
            }
            
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child("TotalBooks")
            var v =  [String:String]()
            for i in 0...epubs[0].1.count-1{
                v["\(i)"] = epubs[0].1[i]
            }
            
            ref.removeValue()
            ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
                
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            })
        } else {
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child("TotalBooks")
            ref.observeSingleEvent(of: .value, with: { (snapshot) in
                var i = 0
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    if self.epubs[0].1[0]=="" {
                        self.epubs[0].1[0] = "\(snap.value ?? "0")"
                    } else {
                        self.epubs[0].1.append("\(snap.value ?? "0")")
                    }
                    i+=1
                }
                
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            })
        }
    }
    
    @objc func addBook() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: ["epub"], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        updateBooks()
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
            cell = UITableViewCell(style: .value1, reuseIdentifier: "identifier")
        }
        
        let bookTitle = self.epubs[indexPath.section].1[indexPath.item]
        cell?.textLabel?.text = bookTitle
        cell?.detailTextLabel?.text = self.getTextFromSeconds(seconds: 0)
        if bookTitle != "" {
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(bookTitle)
            ref.observeSingleEvent(of: .value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    if snap.key == "time" {
                        let s = Int("\(snap.value ?? "0")")
                        cell?.detailTextLabel?.text = self.getTextFromSeconds(seconds: s ?? 0)
                    }
                }
            })
        }
        
        return cell!
    }
    
    func getTextFromSeconds(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = seconds / 60 % 60
        let seconds = seconds % 60
        
        return String(format: "%02i:%02i:%02i", hours, minutes, seconds)
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.epubs[section].0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if book {
            let detailVC = self.storyboard?.instantiateViewController(withIdentifier: "DetailVC") as! EpubDetailViewController
            detailVC.epubName = self.epubs[indexPath.section].1[indexPath.item]
            
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(detailVC.epubName!)
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
                    let v = ["page":"0", "section":"0", "current":"0", "update":"none", "time":"0"]
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
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if book {
            if editingStyle == UITableViewCell.EditingStyle.delete {
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let title = self.epubs[indexPath.section].1[indexPath.row]
                let a = title.replacingOccurrences(of: " ", with: "%20")
                let b = documentsURL.absoluteString + a + ".epub"
                let c = documentsURL.absoluteString + a + "DESC.txt"
                let d = documentsURL.absoluteString + a + "/"
                deleteItem(url: URL(string: b)!)
                deleteItem(url: URL(string: c)!)
                deleteItem(url: URL(string: d)!)
                
                let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(title)
                ref.removeValue()
                
                tableView.deleteRows(at: [indexPath], with: UITableView.RowAnimation.automatic)
                
                updateBooks()
            }
        }
    }
}

extension ViewController: UIDocumentPickerDelegate {
    
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let selectedFileURL = urls.first else {
            return
        }
        
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let sandboxFileURL = dir.appendingPathComponent(selectedFileURL.lastPathComponent)
        
        if FileManager.default.fileExists(atPath: sandboxFileURL.path) {
            print("Already exists! Do nothing")
        }
        else {
            
            do {
                try FileManager.default.copyItem(at: selectedFileURL, to: sandboxFileURL)
                print("Copied file!")
                updateBooks()
            }
            catch {
                print("Error: \(error)")
            }
        }
    }
    
    func deleteItem(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            print("Deleted file")
            updateBooks()
        }
        catch {
            print("Error: \(error)")
        }
    }
}
    


