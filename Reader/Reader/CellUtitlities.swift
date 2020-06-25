//
//  CellUtilities.swift
//  Reader
//
//  Created by Anirudh Natarajan on 6/24/20.
//  Copyright © 2020 Anirudh Natarajan. All rights reserved.
//

import Foundation
import UIKit

public protocol Reusable: class, NSObjectProtocol {
    static var reusableIdentifier: String { get }
}

public extension Reusable {
    static var reusableIdentifier: String {
        return String(describing: Self.self)
    }
}

public protocol Nibable: class, NSObjectProtocol {
    static var nib: UINib { get }
    static var nibName: String { get }
}

public extension Nibable {
    static var nib: UINib { return UINib(nibName: String(describing: Self.self), bundle: Bundle(for: self)) }
    static var nibName: String { return String(describing: Self.self) }
}

extension UITableViewCell: Reusable, Nibable { }
extension UICollectionReusableView: Reusable, Nibable { }
