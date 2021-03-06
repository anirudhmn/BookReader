//
//  TextExtractorViewController.swift
//  Reader
//
//  Created by Anirudh Natarajan on 6/24/20.
//  Copyright © 2020 Anirudh Natarajan. All rights reserved.
//

import UIKit
import EpubExtractor
import Firebase
import PDFKit

class TextExtractorViewController: UIViewController {
    
    @IBOutlet var leftPage: UILabel!
    @IBOutlet var rightPage: UILabel!
    @IBOutlet var pagesTotalLabel: UILabel!
    @IBOutlet var pagesSectionLabel: UILabel!
    
    var epub: Epub!
    var bookName = ""
    var section = 0
    var page = 0
    var book: [[String]] = [[String]]()
    let spacing: CGFloat = 13
    var fontSize: CGFloat = 20
    let bigThreshold: CGFloat = 2200
    
    var totalPages = 0
    var currentPage = 0
    var pagesSection = 0
    
    var startTime = Date.init()
    var pastTime = 0
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        UIApplication.shared.isIdleTimerDisabled = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let style = NSMutableParagraphStyle()
        style.lineSpacing = spacing
        style.alignment = .justified
        
        #if targetEnvironment(macCatalyst)
            if self.view.frame.size.width > bigThreshold {
                fontSize = 28
            } else {
                fontSize = 25
            }
        #endif
        
        let font = UIFont(name: "Georgia", size: fontSize)
        
        let attributes = [NSAttributedString.Key.paragraphStyle: style, NSAttributedString.Key.font: font]
        
        leftPage.attributedText = NSAttributedString(string: leftPage.text ?? "ok", attributes: attributes)
        rightPage.attributedText = NSAttributedString(string: rightPage.text ?? "ok", attributes: attributes)
        
        leftPage.adjustsFontSizeToFitWidth = true
        leftPage.minimumScaleFactor = 0.5
        leftPage.lineBreakMode = .byClipping
        leftPage.numberOfLines = 0
        
        rightPage.adjustsFontSizeToFitWidth = true
        rightPage.minimumScaleFactor = 0.5
        rightPage.lineBreakMode = .byClipping
        rightPage.numberOfLines = 0
        
        var sections = extractText()
        if sections.count > 2 {
            sections.remove(at: 0)
        }
        (book, totalPages) = getPagedBook(sections: sections)
        
        let rightSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        rightSwipe.direction = .right
        let leftSwipe = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(sender:)))
        leftSwipe.direction = .left
        
        view.addGestureRecognizer(rightSwipe)
        view.addGestureRecognizer(leftSwipe)
        
        let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(bookName)
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            for child in snapshot.children {
                let snap = child as! DataSnapshot
                let key = snap.key
                if key == "page" {
                    self.page = Int("\(snap.value ?? 0)")!
                } else if key == "section" {
                    self.section = Int("\(snap.value ?? 0)")!
                } else if key == "current" {
                    self.currentPage = Int("\(snap.value ?? 0)")!
                } else if key == "time" {
                    self.pastTime = Int("\(snap.value ?? 0)")!
                }
            }
            self.pagesSection = self.book[self.section].count
            self.updateText(animated: "none")
        })
        
        ref.observe(.childChanged) { (snapshot) in
            if snapshot.key == "update" {
                let val = "\(snapshot.value ?? "none")"
                if val == "next" {
                    self.nextPage()
                } else if val == "previous" {
                    self.previousPage()
                } else if val == "page" {
                    self.updateCurrentPage()
                }
            } else if snapshot.key == "search" {
                let val = "\(snapshot.value ?? "")"
                self.searchText(phrase: val)
            }
        }
    }
    
    @objc func handleSwipe(sender: UISwipeGestureRecognizer) {
        if sender.state == .ended {
            var delay = 0.01
            #if targetEnvironment(macCatalyst)
                delay = 0.005
            #endif
            
            switch sender.direction {
                case .right:
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.previousPage()
                    }
                case .left:
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        self.nextPage()
                    }
                default:
                    break
            }
        }
    }

    func nextPage() {
        if page==pagesSection-1 {
            page += 1
            currentPage += 1
        } else {
            page += 2
            currentPage += 2
        }
        if page >= pagesSection {
            section += 1
            page = 0
            if section >= book.count {
                section = book.count - 1
                page = book[section].count - 1
                currentPage = totalPages
            }
            pagesSection = book[section].count
        }
        
        updateText(animated: "next")
    }
    
    func previousPage() {
        page -= 2
        currentPage -= 2
        if page < 0 {
            section -= 1
            if section < 0 {
                section = 0
                page = 0
                currentPage = 0
            } else {
                page = book[section].count-2
            }
            pagesSection = book[section].count
        }
        
        updateText(animated: "previous")
    }
    
    func searchText(phrase: String) {
        var searchResults = ""
        let flat = book.flatMap{$0}
        for i in 0...flat.count-1 {
            if flat[i].lowercased().contains(phrase.lowercased()){
                searchResults += "\(i+2), "
            }
        }
        searchResults = String(searchResults.dropLast(2))
        
        let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(bookName)
        var v = ["searchResults":""]
        ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
            if err != nil {
                print(err)
                return
            }
        })
        v = ["searchResults":searchResults]
        ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
            if err != nil {
                print(err)
                return
            }
        })
    }
    
    func updateText(animated: String) {
        if animated == "next" {
            let flipPage = rightPage.clone()
            view.addSubview(flipPage)
            
            rightPage.text = book[section][page]
            if book[section].count - 1 > page+1 {
                flipPage.text = book[section][page+1]
            } else {
                flipPage.text = ""
            }
            
            let transitionOptions: UIView.AnimationOptions = [.transitionFlipFromRight, .allowAnimatedContent]
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.5) {
                    self.rightPage.center = self.leftPage.center
                    self.leftPage.alpha = 0
                }
                UIView.transition(with: self.rightPage, duration: 0.5, options: transitionOptions, animations: {
                    
                }) { (completed) in
                    self.leftPage.text = self.rightPage.text
                    self.rightPage.text = flipPage.text
                    self.rightPage.center = flipPage.center
                    flipPage.removeFromSuperview()
                    self.leftPage.alpha = 1
                }
            }
        } else if animated == "previous" {
            let flipPage = leftPage.clone()
            view.addSubview(flipPage)
            
            flipPage.text = book[section][page]
            if book[section].count - 1 > page+1 {
                leftPage.text = book[section][page+1]
            } else {
                leftPage.text = ""
            }
            
            let transitionOptions: UIView.AnimationOptions = [.transitionFlipFromLeft, .allowAnimatedContent]
            DispatchQueue.main.async {
                UIView.animate(withDuration: 0.5) {
                    self.leftPage.center = self.rightPage.center
                    self.rightPage.alpha = 0
                }
                UIView.transition(with: self.leftPage, duration: 0.5, options: transitionOptions, animations: {
                    
                }) { (completed) in
                    self.rightPage.text = self.leftPage.text
                    self.leftPage.text = flipPage.text
                    self.leftPage.center = flipPage.center
                    flipPage.removeFromSuperview()
                    self.rightPage.alpha = 1
                }
            }
        } else {
            leftPage.text = book[section][page]
            if book[section].count - 1 > page+1 {
                rightPage.text = book[section][page+1]
            } else {
                rightPage.text = ""
            }
        }
        
        pagesTotalLabel.text = "Page \(currentPage+1)/\(totalPages+1)"
        pagesSectionLabel.text = "\(pagesSection-page+1) pages left in this section"
        
        let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(bookName)
        let time = Date.init().seconds(from: startTime) + pastTime
        let v = ["page":"\(page)", "section":"\(section)", "current":"\(currentPage)", "time":"\(time)"]
        ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
            if err != nil {
                print(err)
                return
            }
        })
    }
    
    func updateCurrentPage() {
        let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(userID).child(bookName)
        ref.observeSingleEvent(of: .value, with: { (snapshot) in
            var animate = "previous"
            for child in snapshot.children {
                let snap = child as! DataSnapshot
                let key = snap.key
                if key == "current" {
                    let n = Int("\(snap.value ?? 0)")!
                    if n < self.currentPage {
                        animate = "previous"
                    } else if n > self.currentPage {
                        animate = "next"
                    }
                    self.currentPage = n
                }
            }
            var pageCounter = self.currentPage
            self.page = 0
            self.section = 0
            for s in self.book {
                if pageCounter > s.count {
                    if s == self.book.last {
                        self.page = s.count-1
                        self.currentPage = self.totalPages
                        self.pagesSection = s.count
                    } else {
                        pageCounter -= s.count
                        self.section += 1
                    }
                } else {
                    self.page = pageCounter-1
                    self.pagesSection = self.book[self.section].count
                    if self.page <= 0 {
                        self.page = 0
                    }
                    break
                }
            }
            self.updateText(animated: animate)
        })
    }
    
    func getPagedBook(sections: [String]) -> ([[String]], Int) {
        let screenSize = self.view.frame.size
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: documentsURL, includingPropertiesForKeys: nil)
            for i in fileURLs {
                let a = bookName.replacingOccurrences(of: " ", with: "%20")
                if screenSize.width > bigThreshold {
                    if i.absoluteString.contains("\(a)DESCBig.txt") {
                        do {
                            print("Found existing file.")
                            let description = try String(contentsOf: i, encoding: .utf8)
                            return arrayFromDesc(desc: description)
                        }
                        catch {
                            print(error)
                        }
                    }
                } else {
                    if i.absoluteString.contains("\(a)DESC.txt") {
                        do {
                            print("Found existing file.")
                            let description = try String(contentsOf: i, encoding: .utf8)
                            return arrayFromDesc(desc: description)
                        }
                        catch {
                            print(error)
                        }
                    }
                }
            }
        } catch {
           print("Error while enumerating files \(documentsURL.path): \(error.localizedDescription)")
       }
        
        var book:[[String]] = []
        var pages = 0
        
        if sections.count > 0 {
            for i in 0...sections.count-1 {
                let sectionText = sections[i]
                
                book.append([String]())
                var sectionWords = sectionText.words
                let maxHeight = screenSize.height - (27+55) - spacing*spacing*2
                var excerpt = ""
                
                while sectionWords != [] {
                    (excerpt, sectionWords) = extractHeight(withConstrainedWidth: screenSize.width/2 - (15+20+30), font: leftPage.font!, maxHeight: maxHeight, wordsArray: sectionWords)
                    book[i].append(excerpt)
                    pages += 1
                }
            }
            
            let data:NSData = book.description.data(using: .utf8)! as NSData
            let destinationPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
            if screenSize.width > bigThreshold {
                data.write(toFile: "\(destinationPath ?? "")/\(bookName)DESCBig.txt", atomically: true)
            } else {
                data.write(toFile: "\(destinationPath ?? "")/\(bookName)DESC.txt", atomically: true)
            }
        }
        return (book, pages)
    }
    
    func extractText() -> [String] {
        var sections = [String]()
        
        if epubFile {
            for spine in epub.spines {
                do {
                    sections.append(try epub.content(forSpine: spine))
                } catch {
                    print("there was an error: \(error)")
                }
            }
        } else {
            let destinationPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
            let destinationURL = URL(string: destinationPath!)?.appendingPathComponent(bookName)
            
            let fileManager = FileManager.default
            let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let a = bookName.replacingOccurrences(of: " ", with: "%20")
            let b = documentsURL.absoluteString + a + ".pdf"
            let fileURL = URL(string: b)!
            sections.append(PDFDocument(url: fileURL)?.string ?? "Error")
        }
        return sections
    }
    
    func extractHeight(withConstrainedWidth width: CGFloat, font: UIFont, maxHeight: CGFloat, wordsArray: [String]) -> (String, [String]) {
        var words = wordsArray
        var excerpt = ""
        
        while (excerpt.height(withConstrainedWidth: width, font: font) < maxHeight) {
            excerpt.append(contentsOf: words[0])
            words.remove(at: 0)
            if words.count-1 >= 1 {
                if excerpt.height(withConstrainedWidth: width, font: font) + words[1].height(withConstrainedWidth: width, font: font) > maxHeight {
                    break
                }
            }
            if words.count-1<=0 {
                break
            }
        }
        
        return (excerpt, words)
    }
    
    func arrayFromDesc(desc: String) -> ([[String]], Int) {
        var book:[[String]] = []
        var z = desc.components(separatedBy: "], [")
        z[0] = String(z[0].dropFirst())
        z[z.count-1] = String(z[z.count-1].dropLast())
        var count = 0
        for i in z {
            let (a,b) = stringToArray(str: i)
            book.append(a)
            count += b
        }
        
        return (book, count)
    }
    
    func stringToArray(str: String) -> ([String], Int) {
        var pages = str.components(separatedBy: "\", \"")
        pages[0] = String(pages[0].dropFirst())
        pages[pages.count-1] = String(pages[pages.count-1].dropLast())
        for i in 0...pages.count-1 {
            pages[i] = pages[i].replacingOccurrences(of: "\\n", with: "\n")
            pages[i] = pages[i].replacingOccurrences(of: "\\\"", with: "\"")
            pages[i] = pages[i].replacingOccurrences(of: "\\'", with: "\'")
        }
        
        return (pages, pages.count)
    }
}

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect, options: .usesLineFragmentOrigin, attributes: [NSAttributedString.Key.font: font], context: nil)

        return ceil(boundingBox.height)
    }
    
    var lines: [String] {
        return self.components(separatedBy: "\n")
    }
    
    var words: [String] {
        var array = [String]()
        for i in lines {
            let a = i.split(separator: " ")
            for j in a {
                array.append(String(j) + " ")
            }
            array.append("\n")
        }
        return array
    }
}

extension Date {
    func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
}

extension UILabel{
    func clone() -> UILabel {
        let label = UILabel(frame: frame)
        label.text = text
        label.font = font
        label.textColor = textColor
        label.shadowColor = shadowColor
        label.shadowOffset = shadowOffset
        label.textAlignment = textAlignment
        label.lineBreakMode = lineBreakMode
        label.attributedText = attributedText
        label.highlightedTextColor = highlightedTextColor
        label.isHighlighted = isHighlighted
        label.isUserInteractionEnabled = isUserInteractionEnabled
        label.isEnabled = isEnabled
        label.numberOfLines = numberOfLines
        label.adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth
        label.baselineAdjustment = baselineAdjustment
        label.minimumScaleFactor = minimumScaleFactor
        label.allowsDefaultTighteningForTruncation = allowsDefaultTighteningForTruncation
        label.preferredMaxLayoutWidth = preferredMaxLayoutWidth
        return label
    }
}
