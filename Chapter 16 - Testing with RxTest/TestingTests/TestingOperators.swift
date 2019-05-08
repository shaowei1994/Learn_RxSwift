/*
 * Copyright (c) 2014-2017 Razeware LLC
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

import XCTest
import RxSwift
import RxTest
import RxBlocking

class TestingOperators : XCTestCase {
    
    var scheduler: TestScheduler! // an instance of the `TestScheduler` that'll be used in each test
    var subscription: Disposable! // holds the subscription in each test
    
    // this method is called before each test case begins
    override func setUp() {
        super.setUp()
        
        // start the test scheduler at the beginning time of the test
        scheduler = TestScheduler(initialClock: 0)
        
    }
    
    // this method is called at the completion of each test. Scheduled the disposal of the test's subcription at 1s.
    override func tearDown() {
        scheduler.scheduleAt(1000) {
            self.subscription.dispose()
        }
        
        super.tearDown()
    }
    
    // as with all tests using XCTest, the method name must begin with `test`
    func testAmb() {
        
        // 1 - Create an `observableA` using the scheduler's `createHotObservable(_:)` method
        let observableA = scheduler.createHotObservable([
            // 2 - Use `next(_:_:) to add `.next` events onto `observableA` at the designated times in ms
            next(100, "a"),
            next(200, "b"),
            next(300, "c")
        ])
        
        // 3 - Create `observableB` hot observable
        let observableB = scheduler.createHotObservable([
            // 4 - Add .next events to `observableB` at the designated times and with the specified values
            next(90, "1"),
            next(200, "2"),
            next(300, "3")
        ])
        
        // Create an observer using the scheduler's `createObserver(_:)` method, with a type hint of String
        let observer = scheduler.createObserver(String.self) // String.self = Static MetaType
        
        // use the `amb` operator and assign the result to a local constant
        let ambObservable = observableA.amb(observableB)
        
        // Tell the `scheduler` to schedule an action at a specific time (at 0 ms)
        scheduler.scheduleAt(0) {
            self.subscription = ambObservable.subscribe(observer)
        }
        
        scheduler.start()
        
        // use `map` on the `observer's event` property to access each vvent's element.
        let results = observer.events.map {
            $0.value.element!
        }
        
        XCTAssertEqual(results, ["1", "2", "3"])
    }
    
    func testFilter() {
        
        // 1 - create an `observer` while type-hinting Int.
        let observer = scheduler.createObserver(Int.self)
        
        // 2 - create a hot observable that schedules a `.next` event every second for 5 seconds
        let observable = scheduler.createHotObservable([
            next(100, 1),
            next(200, 2),
            next(300, 3),
            next(400, 2),
            next(500, 1)
        ])
        
        // 3 - create the `filterObservable` to hold the result of using `filter` on `observable` with a predicate that requires the element value to be less than 3.
        let filterObservable = observable.filter {
            $0 < 3
        }
        
        // 4 - Schedule the subscription to start at time 0 and assign it to the `subscription` property so it will be disposed of in `tearDown()`.
        scheduler.scheduleAt(0) {
            self.subscription = filterObservable.subscribe(observer)
        }
        
        // 5 - Start the scheduler
        scheduler.start()
        
        // 6 - Collect the result
        let results = observer.events.map {
            $0.value.element!
        }
        
        // 7 - Assert that the results are what you expected
        XCTAssertEqual(results, [1, 2, 2, 1])
    }
    
    func testToArray() {
        /*:
         RxBlocking, another library housed within RxSwift
         - has own pod and must be separately imported
         - primarly purpose is to convert an observable to a `BlockingObservable` via its `toBlocking(timeout:)` method
            - block the current thread until the observable terminates or till the timeout time --> turns an asynchronous operation into a synchronous one
         */
        
        // 1 - Create a concurrent scheduler to run this asynchronous test, with the result quality of service
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        // 2 - Create an observable to hold the result of subscribing to an observable of two integers on the `scheduler`
        let toArrayObservable = Observable.of(1, 2).subscribeOn(scheduler)
        
        // 3 - Use `toArray()` on the result of calling `toBlocking()` on `toArrayObservable` and assert that the return value from `toArray` equals the expected result.
        // `toBlocking()` converts `toArrayObservable` to a blocking observable, blocking the thread spawn by the scheduler until it terminates.
        XCTAssertEqual(try! toArrayObservable.toBlocking().toArray(), [1, 2])
    }
    
    func testToArrayMaterialized() {
        
        // 1 - Create a scheduler and observable to test, the same as in the previous test
        let scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
        
        let toArrayObservable = Observable.of(1, 2).subscribeOn(scheduler)
        
        // 2 - Call `toBlocking` and `materialize` on the observable, and assign the reuslt to a local constant `result`
        let result = toArrayObservable
            .toBlocking()
            .materialize()
        
        // 3 - Switch on `result` and handle each case
        switch result {
        case .completed(elements: let elements):
            XCTAssertEqual(elements, [1, 2])
        case .failed(elements: _, error: let error):
            XCTFail(error.localizedDescription)
        }
    }
}
