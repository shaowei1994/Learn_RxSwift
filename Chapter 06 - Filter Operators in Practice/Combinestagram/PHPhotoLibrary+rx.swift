//
//  PHPhotoLibrary+rx.swift
//  Combinestagram
//
//  Created by Shao-Wei Liang on 2019-01-14.
//  Copyright © 2019 Underplot ltd. All rights reserved.
//

import Foundation
import Photos
import RxSwift

extension PHPhotoLibrary {
    // adds a new `Observable<Bool>` property named `authorize` on PHPhotoLibrary
    static var authorized: Observable<Bool> {
        return Observable.create { observer in
            // Usage of DispatchQueue.main.async {...}: generally, your observable should not block the current thread because that could block your UI, prevent other subscriptions or other consequences.
            DispatchQueue.main.async {
                // if the status has already been authorized -> true
                if authorizationStatus() == .authorized {
                    observer.onNext(true)
                    observer.onCompleted()
                } else {
                    // else -> false
                    observer.onNext(false)
                    requestAuthorization { newStatus in
                        observer.onNext(newStatus == .authorized)
                        observer.onCompleted()
                    }
                }
            }
            return Disposables.create()
        }
    }
}
