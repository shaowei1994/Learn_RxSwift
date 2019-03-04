/*
 * Copyright (c) 2014-2016 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import Foundation
import CoreLocation
import RxSwift
import RxCocoa

extension CLLocationManager: HasDelegate {
    public typealias Delegate = CLLocationManagerDelegate
}

class RxCLLocationManagerDelegateProxy: DelegateProxy<CLLocationManager, CLLocationManagerDelegate>, DelegateProxyType, CLLocationManagerDelegate {

    public weak private(set) var locationManager: CLLocationManager?
    
    // The following initializer and function is used to initialize the delegate and register all implementations, which will be the proxy used to drive the daa from the `CLLocationManager` instance to the connected `Observables`
    public init(locationManager: ParentObject) {
        self.locationManager = locationManager
        super.init(parentObject: locationManager, delegateProxy: RxCLLocationManagerDelegateProxy.self)
    }
    
    // register the proper implementation
    static func registerKnownImplementations() {
        self.register {
            RxCLLocationManagerDelegateProxy(locationManager: $0)
        }
    }
}

// Create the observable to observe the change of location, using the proxy delegate
// Using the `Reactive` extension will expose the method within that extension in the `rx` namespace for an instance of `CLLocationManager`
extension Reactive where Base: CLLocationManager {
    
    public var delegate: DelegateProxy<CLLocationManager, CLLocationManagerDelegate> {
        return RxCLLocationManagerDelegateProxy.proxy(for: base)
    }
    
    // With this function, the delegate used as the proxy will listen to all the calls of `didUpdateLocations`, getting the data and casting it to an array of `CLLocation`
    // `methodInvoked(_:)` is part of the Obj-C code present in RxCocoa and is basically a low-level observer for delegates - returns an observable that sends `next` events whenever the specified method is invoked
    var didUpdateLocations: Observable<[CLLocation]> {
        return delegate.methodInvoked(#selector(CLLocationManagerDelegate.locationManager(_:didUpdateLocations:)))
            .map{ parameters in
                return parameters[1] as! [CLLocation]
        }
    }
}
