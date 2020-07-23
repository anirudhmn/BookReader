//
//  EpubDetailViewController.swift
//  Reader
//
//  Created by Anirudh Natarajan on 6/24/20.
//  Copyright © 2020 Anirudh Natarajan. All rights reserved.
//

import UIKit
import EpubExtractor

class EpubDetailViewController: UIViewController {
    private let epubExtractor = EpubExtractor()
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var loadingView: UIView!
    
    var bookName: String? {
        didSet {
            if epubFile {
                self.epubExtractor.delegate = self
                let destinationPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first
                let destinationURL = URL(string: destinationPath!)?.appendingPathComponent(bookName!)
                
                let fileManager = FileManager.default
                let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let a = bookName?.replacingOccurrences(of: " ", with: "%20")
                let b = documentsURL.absoluteString + a! + ".epub"
                let fileURL = URL(string: b)!
                
                self.epubExtractor.extractEpub(epubURL: fileURL, destinationFolder: destinationURL!)
            }
        }
    }
    
    fileprivate var epub: Epub? {
        didSet {
            self.epubPlainChapters = self.generatePlainChapters(chapters: self.epub?.chapters ?? [])
        }
    }
    
    fileprivate var epubPlainChapters: [(chapter: ChapterItem, indentationLevel: Int)] = []
    
    static var needsFullScreen = true
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if Self.needsFullScreen {
            (NSClassFromString("NSApplication")?.value(forKeyPath: "sharedApplication.windows") as? [AnyObject])?.first?.perform(Selector("toggleFullScreen:"))
            Self.needsFullScreen = false
        }
        loadingView.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.register(ImageCell.self, forCellReuseIdentifier: ImageCell.reusableIdentifier)
        
        let barButtonItem = UIBarButtonItem(title: "Extract text", style: .done, target: self, action: #selector(extractTextPressed))
        navigationItem.rightBarButtonItems = [barButtonItem]
    }
    
    @objc func extractTextPressed() {
        loadingView.isHidden = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            let vc = self.storyboard?.instantiateViewController(withIdentifier: "TextExtractor") as! TextExtractorViewController
            if epubFile {
                guard let epub = self.epub else { print("no epub"); return }
                vc.epub = epub
            }
            vc.bookName = self.bookName!
            
            self.navigationController?.pushViewController(vc, animated: true)
        }
    }
    
    private func generatePlainChapters(chapters: [ChapterItem], currentIndentationLevel: Int = 0) -> [(chapter: ChapterItem, indentationLevel: Int)] {
        return chapters.reduce([], { (result, chapter) -> [(chapter: ChapterItem, indentationLevel: Int)] in
            var result = result
            
            result.append((chapter, currentIndentationLevel))
            
            result.append(contentsOf: self.generatePlainChapters(chapters: chapter.subChapters, currentIndentationLevel: currentIndentationLevel + 1))
            
            return result
        })
    }
    
}

private let detailSection = 0
private let imageIndex = 0
private let titleIndex = 1
private let authorIndex = 2
private let publisherIndex = 3
private let languageIndex = 4

extension EpubDetailViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == detailSection {
            return 5
        } else {
            return self.epubPlainChapters.count
        }
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == detailSection {
            return "Details"
        } else {
            return "Chapters"
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if indexPath.section == detailSection {
            switch indexPath.item {
            case imageIndex:
                return self.imageCell(indexPath: indexPath)
            case titleIndex:
                return self.titleCell(indexPath: indexPath)
            case authorIndex:
                return self.authorCell(indexPath: indexPath)
            case publisherIndex:
                return self.publisherCell(indexPath: indexPath)
            case languageIndex:
                return self.languageCell(indexPath: indexPath)
            default:
                return UITableViewCell()
            }
        } else {
            return chapterCell(indexPath: indexPath)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == detailSection && indexPath.item == imageIndex {
            return 250
        }
        
        return UITableView.automaticDimension
    }
    
    private func imageCell(indexPath: IndexPath) -> UITableViewCell {
        let cell = self.tableView.dequeueReusableCell(withIdentifier: ImageCell.reusableIdentifier, for: indexPath) as! ImageCell
        
        if let coverPath = self.epub?.coverURL?.path {
            cell.coverImageView.image = UIImage(contentsOfFile: coverPath)
        }
        
        return cell
    }
    
    private func titleCell(indexPath: IndexPath) -> UITableViewCell {
        return self.commonCell(indexPath: indexPath, title: "Title", value: self.epub?.title)
    }
    
    private func authorCell(indexPath: IndexPath) -> UITableViewCell {
        return self.commonCell(indexPath: indexPath, title: "Author", value: self.epub?.author)
    }
    
    private func publisherCell(indexPath: IndexPath) -> UITableViewCell {
        return self.commonCell(indexPath: indexPath, title: "Publisher", value: self.epub?.publisher)
    }
    
    private func languageCell(indexPath: IndexPath) -> UITableViewCell {
        return self.commonCell(indexPath: indexPath, title: "Language", value: self.epub?.language)
    }
    
    private func identifierCell(indexPath: IndexPath) -> UITableViewCell {
        return self.commonCell(indexPath: indexPath, title: "Identifier", value: self.epub?.identifier)
    }
    
    private func chapterCell(indexPath: IndexPath) -> UITableViewCell {
        var cell = self.tableView.dequeueReusableCell(withIdentifier: "ChapterCell")
        
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: "ChapterCell")
        }
        
        let plainChapter = self.epubPlainChapters[indexPath.item]
        
        cell?.textLabel?.text = plainChapter.chapter.label
        cell?.textLabel?.numberOfLines = 0
        cell?.indentationLevel = plainChapter.indentationLevel
        
        return cell!
    }
    
    private func commonCell(indexPath: IndexPath, title: String, value: String?) -> UITableViewCell {
        var cell = self.tableView.dequeueReusableCell(withIdentifier: "CommonCell")
        
        if cell == nil {
            cell = UITableViewCell(style: .value1, reuseIdentifier: "CommonCell")
        }
        
        cell?.textLabel?.text = title
        cell?.detailTextLabel?.text = value
        
        return cell!
    }
}

extension EpubDetailViewController: EpubExtractorDelegate {
    func epubExactorDidExtractEpub(_ epub: Epub) {
        self.epub = epub
        self.tableView?.reloadData()
    }
    
    func epubExtractorDidFail(error: Error?) {
        print("error while extracting the epub: \(String(describing: error))")
    }
}
