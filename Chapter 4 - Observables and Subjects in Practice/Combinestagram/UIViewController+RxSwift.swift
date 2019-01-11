//
//  UIViewController+RxSwift.swift
//  Combinestagram
//
//  Created by Shao-Wei Liang on 2019-01-11.
//  Copyright © 2019 Underplot ltd. All rights reserved.
//

import Foundation
import RxSwift

extension UIViewController {
    func alert(title: String, text: String?) -> Completable {
        return Completable.create { [weak self] completable in
            let alertViewController = UIAlertController(title: title, message: text, preferredStyle: .alert)
            alertViewController.addAction(UIAlertAction(title: "Close", style: .default) {_ in
                completable(.completed)
            })
            self?.present(alertViewController, animated: true, completion: nil)
            return Disposables.create {
                self?.dismiss(animated: true, completion: nil)
            }
        }
    }
}
