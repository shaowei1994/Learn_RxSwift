//: Please build the scheme 'RxSwiftPlayground' first
import UIKit
import RxSwift
import RxCocoa

let elementsPerSecond = 1
let maxElements = 5
let replayedElements = 1
let replayDelay: TimeInterval = 3

//let sourceObservable: Observable = Observable<Int>
//    .create { observer in
//        var value = 1
//        // creates an repeating timer
//        let timer = DispatchSource.timer(interval: 1.0 / Double(elementsPerSecond), queue: .main) {
//            if value <= maxElements {
//                observer.onNext(value)
//                value += 1
//            }
//        }
//
//        return Disposables.create {
//            timer.suspend()
//        }
//    }
//    // the `replay(_:)` operator creates a new sequence which records the last `replayedElements` emitted by the source observable. Every time a new observer subscribes, it immediately receives the buffered elements and keeps receiving any new elements.
//    .replay(replayedElements)

// used `DispatchSouce.timer(_:queue:)` to create a timer and feed observers with values.
// Since `Observable.interval(_:scheduler:)` generates an observable sequence, subscriptions can simply `dispose()`. the returned disposable to cancel the subscription and stop the timer.
let sourceObservable = Observable<Int>
    .interval(RxTimeInterval(1.0 / Double(elementsPerSecond)), scheduler: MainScheduler.instance)
    .replay(replayedElements)
//    // replays everything prior to the delay
//    .replayAll()

let sourceTimeline = TimelineView<Int>.make()
let replayedTimeline = TimelineView<Int>.make()

// Use `UIStackView` for convenience, which will display the source observable as viewed by an immediate subscriber
let stack = UIStackView.makeVertical([
    UILabel.makeTitle("replay"),
    UILabel.make("Emit \(elementsPerSecond) per second:"),
    sourceTimeline,
    UILabel.make("Replay \(replayedElements) after \(replayDelay) sec:"),
    replayedTimeline
])

// The `TimelineView` class implements the `ObserverType` RxSwift protocol.
// Thus, we can subscribe it to an observable sequence and it will receive the sequence's events - every time a new event occurs, the view will displays it on the timeline.
_ = sourceObservable.subscribe(sourceTimeline)

DispatchQueue.main.asyncAfter(deadline: .now() + replayDelay) {
    // this displays elements received byt he second subscription in another timeline view.
    _ = sourceObservable.subscribe(replayedTimeline)
}

// Since `replay(_:)` creates a "connectable observable", we need to connect it to its underlying source to start receiving items else the subscribers will never receive anything.
// Note that "connectable observables" are a special class of observables which will not start emitting items until `connect()` method is called.
_ = sourceObservable.connect()

// set up the host view in which the stack view will display.
let hostView = setupHostView()
hostView.addSubview(stack)
hostView


// Support code -- DO NOT REMOVE
class TimelineView<E>: TimelineViewBase, ObserverType where E: CustomStringConvertible {
    static func make() -> TimelineView<E> {
        return TimelineView(width: 400, height: 100)
    }
    public func on(_ event: Event<E>) {
        switch event {
        case .next(let value):
            add(.Next(String(describing: value)))
        case .completed:
            add(.Completed())
        case .error(_):
            add(.Error())
        }
    }
}
/*:
 Copyright (c) 2014-2017 Razeware LLC
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */
