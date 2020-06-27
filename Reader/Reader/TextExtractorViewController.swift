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

class TextExtractorViewController: UIViewController {
    
    @IBOutlet var leftPage: UILabel!
    @IBOutlet var rightPage: UILabel!
    @IBOutlet var pagesTotalLabel: UILabel!
    @IBOutlet var pagesSectionLabel: UILabel!
    
    var epub: Epub!
    var epubName = ""
    var section = 0
    var page = 0
    var book: [[String]] = [[String]]()
    let spacing: CGFloat = 13
    
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
        
        let font = UIFont(name: "Georgia", size: 22)
        
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
        if sections.count > 1 {
            sections.remove(at: 0)
        }
        (book, totalPages) = getPagedBook(sections: sections)
        
        let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(epubName)
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
            self.updateText()
        })
        
        ref.observe(.childChanged) { (snapshot) in
            if snapshot.key == "flip"{
                let val = "\(snapshot.value ?? "none")"
                let flip = val.split(separator: "_")[0]
                if flip == "right" {
                    self.nextPage()
                } else if flip == "left" {
                    self.previousPage()
                }
            }
        }
    }

    func nextPage() {
        page += 2
        currentPage += 2
        if page >= book[section].count {
            section += 1
            page = 0
            if section >= book.count {
                section = book.count - 1
                page = book[section].count - 1
                currentPage = totalPages
            }
            pagesSection = book[section].count
        }
        
        updateText()
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
        
        updateText()
    }
    
    func updateText() {
        leftPage.text = book[section][page]
        if book[section].count - 1 > page+1 {
            rightPage.text = book[section][page+1]
        } else {
            rightPage.text = ""
        }
        
        pagesTotalLabel.text = "Page \(currentPage)/\(totalPages)"
        pagesSectionLabel.text = "\(pagesSection-page) pages left in this section"
        
        let ref = Database.database().reference(fromURL: "https://epubreader-6d14e.firebaseio.com").child(epubName)
        let time = Date.init().seconds(from: startTime) + pastTime
        let v = ["page":"\(page)", "section":"\(section)", "current":"\(currentPage)", "time":"\(time)"]
        ref.updateChildValues(v, withCompletionBlock: { (err, ref) in
            if err != nil {
                print(err)
                return
            }
        })
    }
    
    func getPagedBook(sections: [String]) -> ([[String]], Int) {
        var book:[[String]] = []
        var pages = 0
        
        for i in 0...sections.count-1 {
            let screenSize = self.view.frame.size
            let sectionText = sections[i]
            
            book.append([String]())
            var sectionLines = sectionText.lines
            let maxHeight = screenSize.height - (27+55) - spacing*spacing*1.7
            var excerpt = ""
            
            while sectionLines != [] {
                (excerpt, sectionLines) = extractHeight(withConstrainedWidth: screenSize.width/2 - (15+20+30), font: leftPage.font!, maxHeight: maxHeight, linesArray: sectionLines)
                book[i].append(excerpt)
                pages += 1
            }
        }
        
        return (book, pages)
    }
    
    func extractText() -> [String] {
        var sections = [String]()
        
        var i = 0
        for spine in epub.spines {
            i += 1
            do {
                sections.append(try epub.content(forSpine: spine))
            } catch {
                print("there was an error: \(error)")
            }
        }
        return sections
    }
    
    func extractHeight(withConstrainedWidth width: CGFloat, font: UIFont, maxHeight: CGFloat, linesArray: [String]) -> (String, [String]) {
        var lines = linesArray
        var excerpt = ""
        while (excerpt.height(withConstrainedWidth: width, font: font) < maxHeight) {
            excerpt.append(contentsOf: lines[0])
            excerpt.append(contentsOf: "\n")
            lines.remove(at: 0)
            if lines.count-1 >= 1 {
                if excerpt.height(withConstrainedWidth: width, font: font) + lines[1].height(withConstrainedWidth: width, font: font) > maxHeight {
                    break
                }
            }
            if lines.count-1<=0 {
                break
            }
        }
        
        return (excerpt, lines)
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
}

extension Date {
    func seconds(from date: Date) -> Int {
        return Calendar.current.dateComponents([.second], from: date, to: self).second ?? 0
    }
}
