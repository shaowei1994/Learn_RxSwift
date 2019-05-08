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
import RxCocoa
import RxTest
@testable import Testing

class TestingViewModel : XCTestCase {
    
    var viewModel: ViewModel!
    var scheduler: ConcurrentDispatchQueueScheduler!
    
    override func setUp() {
        super.setUp()
        
        // assign `viewModel` an instance of the app's ViewModel class
        viewModel = ViewModel()
        
        // assign `scheduler` an instance of a concurrent scheduler with default qos
        scheduler = ConcurrentDispatchQueueScheduler(qos: .default)
    }
    
    func testColorIsRedWhenHexStringIsFF000_async() {
        
        let disposeBag = DisposeBag()
        
        // 1 - create an expectation to be fulfilled later
        let expect = expectation(description: #function)
        
        // 2 - create the expected test result `expectedColor` as equal to red color
        let expectedColor = UIColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)
        
        // 3 - define the reuslt to be later assigned
        var result: UIColor!
        
        // 4 create a subscription to the view model's color driver. Skip one because the Driver will replay the initial element upon subscription
        viewModel.color.asObservable()
            .skip(1)
            .subscribe(onNext: {
                // 5 - assign the .next event element to result and call fulfull() on the expectation
                result = $0
                expect.fulfill()
            })
            .disposed(by: disposeBag)
        
        // 6 - add a new value onto the view model's hexString input observable (a Variable)
        viewModel.hexString.value = "#ff0000"
        
        // 7 - Wait for expectation to fulfill with a 1s timeout. In the closure, guard for an error and then assert that the expected color equals the actual result.
        waitForExpectations(timeout: 1.0) { error in
            guard error == nil else {
                XCTFail(error!.localizedDescription)
                return
            }
        
            XCTAssertEqual(expectedColor, result)
        }
    }
    
    // Accomplishes the same thign by using `RxBlocking`
    func testColorIsRedWhenHexStringIsFF000() {
        
        // 1 - create the `colorObservable` to hold on to the observable result of subscribing on the concurrent scheduler
        let colorObservable = viewModel.color.asObservable().subscribeOn(scheduler)
        
        // 2 - add a new value onto the view model's hexString input observable
        viewModel.hexString.value = "#ff0000"
        
        // 3 - use guard to optionally bind the result of calling `toBlocking()` with a 1s timeout, catching and printing an error if thrown, and then asserting that the actual result amtches the expected one.
        do {
            guard let result = try colorObservable.toBlocking(timeout: 1.0).first() else { return }
            
            XCTAssertEqual(result, .red)
        } catch {
            print(error)
        }
    }
    
    func testRgbIs010WhenHexStringIs00FF00() {
        
        // 1 - create `rgbObservable` to hold the subscription on the scheduler
        let rgbObservable = viewModel.rgb.asObservable().subscribeOn(scheduler)
        
        // 2 - add a new value onto the view model's hexString input observable
        viewModel.hexString.value = "#00ff00"
        
        // 3 - retrieve the first result of calling `toBlocking` on rgbObservable and then assert that each value matches expectation
        let result = try! rgbObservable.toBlocking().first()!
        
        XCTAssertEqual(0 * 255, result.0)
        XCTAssertEqual(1 * 255, result.1)
        XCTAssertEqual(0 * 255, result.2)
        
    }
    
    func testColorNameIsRayWenderlichGreenWhenHexStringIs006636() {
        
        // 1 - Create the observable
        let colorNameObservable = viewModel.colorName.asObservable().subscribeOn(scheduler)
        
        // 2 - add the test value
        viewModel.hexString.value = "#006636"
        
        // 3 - assert that the actual result matching the expected result
        XCTAssertEqual("rayWenderlichGreen", try! colorNameObservable.toBlocking().first()!)
    }
}
