//
//  ImageCell.swift
//  Reader
//
//  Created by Anirudh Natarajan on 6/24/20.
//  Copyright © 2020 Anirudh Natarajan. All rights reserved.
//

import UIKit

class ImageCell: UITableViewCell {
    var coverImageView: UIImageView!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.coverImageView = UIImageView(frame: self.contentView.frame)
        self.coverImageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.coverImageView.contentMode = .scaleAspectFit
        
        self.contentView.addSubview(self.coverImageView)
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
