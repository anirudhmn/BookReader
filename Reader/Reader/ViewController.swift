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
import AudioToolbox
import MobileCoreServices
import SSZipArchive

var userID = ""
var epubFile = true

class ViewController: UIViewController {
    
    @IBOutlet var tableView: UITableView!
    @IBOutlet var contentView: UIView!
    @IBOutlet var titleLabel: UILabel!
    @IBOutlet var descriptionLabel: UILabel!
    @IBOutlet var inputTextField: UITextField!
    @IBOutlet var backButton: UIButton!
    var backgroundView: UIView! = UIView()
    
    var books = [("Epubs",[String]()), ("Pdfs",[String]())]
    var refreshControl = UIRefreshControl()
    var book = false
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        
        if userID != "" {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        #if targetEnvironment(macCatalyst)
            self.book = true
        #endif
        
        if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
            book = true
        } else if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.phone {
            book = false
        }
        
        contentView.layer.cornerRadius = 10
        contentView.isHidden = true
        backgroundView = UIView(frame: self.view.frame)
        self.view.addSubview(backgroundView)
        backgroundView.backgroundColor = .black
        backgroundView.isHidden = true
        backButton.layer.cornerRadius = 20
        backButton.clipsToBounds = true
        self.view.bringSubviewToFront(contentView)
        backButton.setTitleColor(titleLabel.textColor, for: .normal)
        
        let defaults = UserDefaults.standard
        if let id = defaults.string(forKey: "userID") {
            userID = id
            updateBooks()
        } else {
            showPopup()
        }
        
        if book {
            let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addBook))
            navigationItem.rightBarButtonItems = [addButton]
        }
        
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(self.refresh(_:)), for: .valueChanged)
        tableView.addSubview(refreshControl)
        
        let tap: UITapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.dismissKeyboard))
        backgroundView.addGestureRecognizer(tap)
    }
                
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    func updateBooks() {
        books = [("Epubs",[String]()), ("Pdfs",[String]())]
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
                        
                        self.books[0].1.append(String(c.split(separator: ".")[0]))
                    } else if i.absoluteString.contains("pdf") {
                        let a = i.absoluteString.split(separator: "/")
                        let b = a[a.count-1]
                        let c = b.replacingOccurrences(of: "%20", with: " ")
                        
                        self.books[1].1.append(String(c.split(separator: ".")[0]))
                    }
                }
            } catch {
                print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
            }
            
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child("TotalBooks")
            
            var e =  [String:String]()
            if books[0].1.count != 0 {
                for i in 0...books[0].1.count-1{
                    e["\(i)"] = books[0].1[i]
                }
            }
            
            var p =  [String:String]()
            if books[1].1.count != 0 {
                for i in 0...books[1].1.count-1{
                    p["\(i)"] = books[1].1[i]
                }
            }
            
            ref.removeValue()
            ref.child("epub").updateChildValues(e, withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            })
            ref.child("pdf").updateChildValues(p, withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            })
        } else {
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child("TotalBooks")
            ref.child("epub").observeSingleEvent(of: .value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    self.books[0].1.append("\(snap.value ?? "0")")
                }
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            })
            ref.child("pdf").observeSingleEvent(of: .value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    self.books[1].1.append("\(snap.value ?? "0")")
                }
                self.tableView.reloadData()
                self.refreshControl.endRefreshing()
            })
        }
    }
    
    @objc func addBook() {
        let documentPicker = UIDocumentPickerViewController(documentTypes: [String(kUTTypePDF), String(kUTTypeElectronicPublication)], in: .import)
        documentPicker.delegate = self
        documentPicker.allowsMultipleSelection = false
        present(documentPicker, animated: true, completion: nil)
    }
    
    @objc func refresh(_ sender: AnyObject) {
        updateBooks()
    }
    
    @IBAction func okPressed(_ sender: Any) {
        if book {
            var connected = true
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID)
            ref.observeSingleEvent(of: .value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    if snap.key == "created" {
                        connected = false
                    }
                }
                if connected {
                    UserDefaults.standard.set(userID, forKey: "userID")
                    self.dismissPopup()
                    self.view.bringSubviewToFront(self.tableView)
                    self.updateBooks()
                } else {
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    self.descriptionLabel.text = "Please enter the code on your phone before closing this window:\n\(userID)"
                }
            })
        } else {
            view.endEditing(true)
            if inputTextField.text == "" {
                AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                return
            }
            var works = false
            userID = inputTextField.text!
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID)
            ref.observeSingleEvent(of: .value, with: { (snapshot) in
                for child in snapshot.children {
                    let snap = child as! DataSnapshot
                    if snap.key == "created" {
                        works = true
                    }
                }
                if works {
                    UserDefaults.standard.set(userID, forKey: "userID")
                    self.dismissPopup()
                    self.view.bringSubviewToFront(self.tableView)
                    self.updateBooks()
                    ref.child("created").removeValue()
                } else {
                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                    self.descriptionLabel.text = "The code you entered could not be found. Please try again."
                }
            })
        }
    }
    
    func showPopup() {
        // animate bringing up the popup
        
        backgroundView.alpha = 0
        contentView.center = CGPoint(x: self.view.center.x, y: self.view.frame.height + self.contentView.frame.height)
        
        backgroundView.isHidden = false
        contentView.isHidden = false
        
        if book {
            userID = UIDevice.current.identifierForVendor?.uuidString as! String
            titleLabel.text = "New device established!"
            descriptionLabel.text = "Please enter this code on your phone:\n\(userID)"
            inputTextField.isHidden = true
            
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID)
            ref.updateChildValues(["created":"yes"], withCompletionBlock: { (err, ref) in
                if err != nil {
                    print(err)
                    return
                }
            })
        } else {
            titleLabel.text = "Pair with your device!"
            descriptionLabel.text = "Please enter the code displayed on your reading screen."
            inputTextField.isHidden = false
        }
        
        DispatchQueue.main.async {
            UIView.animate(withDuration: 0.5, animations: {
                self.backgroundView.alpha = 0.66
            })
            UIView.animate(withDuration: 0.7, delay: 0.0, usingSpringWithDamping: 0.5, initialSpringVelocity: 9, options: UIView.AnimationOptions(rawValue: 0), animations: {
                self.contentView.center = self.view.center
            }, completion: { (completed) in
                
            })
        }
        
    }
    
    func dismissPopup(){
        // animate dismissal of popup
        
        UIView.animate(withDuration: 0.33, animations: {
            self.backgroundView.alpha = 0
        }, completion: { (completed) in
            
        })
        UIView.animate(withDuration: 0.33, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 10, options: UIView.AnimationOptions(rawValue: 0), animations: {
            self.contentView.center = CGPoint(x: self.view.center.x, y: self.view.frame.height + self.contentView.frame.height/2)
        }, completion: { (completed) in
            self.backgroundView.isHidden = true
            self.contentView.isHidden = true
        })
    }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.books.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.books[section].1.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: "identifier")
        
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "identifier")
        }
        
        let bookTitle = self.books[indexPath.section].1[indexPath.item]
        cell?.textLabel?.text = bookTitle
        cell?.detailTextLabel?.text = self.getTextFromSeconds(seconds: 0)
        if bookTitle != "" {
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(bookTitle)
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
        return self.books[section].0
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if self.books[indexPath.section].1[indexPath.item] == "" {
            return
        }
        if book {
            let detailVC = self.storyboard?.instantiateViewController(withIdentifier: "DetailVC") as! EpubDetailViewController
            detailVC.bookName = self.books[indexPath.section].1[indexPath.item]
            if indexPath.section == 0 {
                epubFile = true
            } else if indexPath.section == 1 {
                epubFile = false
            }
            
            let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(detailVC.bookName!)
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
                    let v = ["page":"0", "section":"0", "current":"0", "update":"none", "time":"0", "search": "none", "searchResults": "nonee"]
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
            remoteVC.bookName = self.books[indexPath.section].1[indexPath.item]
            self.navigationController?.show(remoteVC, sender: self)
        }
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if book {
            if editingStyle == UITableViewCell.EditingStyle.delete {
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let title = self.books[indexPath.section].1[indexPath.row]
                let a = title.replacingOccurrences(of: " ", with: "%20")
                var b = ""
                if indexPath.section == 0 {
                    b = documentsURL.absoluteString + a + ".epub"
                } else if indexPath.section == 1 {
                    b = documentsURL.absoluteString + a + ".pdf"
                }
                let c = documentsURL.absoluteString + a + "/"
                let d = documentsURL.absoluteString + a + "DESC.txt"
                let e = documentsURL.absoluteString + a + "DESCBig.txt"
                deleteItem(url: URL(string: b)!)
                deleteItem(url: URL(string: c)!)
                deleteItem(url: URL(string: d)!)
                deleteItem(url: URL(string: e)!)
                print(d)
                
                let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(title)
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
                if selectedFileURL.absoluteString.contains("epub") {
                    try FileManager.default.copyItem(at: selectedFileURL, to: sandboxFileURL)
                    print("Copied epub file!")
                } else if selectedFileURL.absoluteString.contains("pdf") {
                    try FileManager.default.copyItem(at: selectedFileURL, to: sandboxFileURL)
                    print("Copied pdf file!")
                }
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
    


