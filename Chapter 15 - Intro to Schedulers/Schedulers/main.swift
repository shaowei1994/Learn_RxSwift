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
import RxSwift

print("\n\n\n===== Schedulers =====\n")

// `globalScheduler` uses a background queue and is created using the Global Dispatch Queue, a concurrent queue.
let globalScheduler = ConcurrentDispatchQueueScheduler(queue: DispatchQueue.global())
let bag = DisposeBag()
let animal = BehaviorSubject(value: "[dog]")


animal
    .subscribeOn(MainScheduler.instance)
    .dump()
    .observeOn(globalScheduler)
    .dumpingSubscription()
    .disposed(by: bag)

/*:
 Background Schedular ( Network Request -> Cache() ) -> MainScheduler ( Subscription )
 - An observable makes a request to a server and retrieves some date. This data is processed by a custom operator named `cache`, which stores the data somewhere. Data is then passed to all subscribers in a different scheduler, most likely the `MainScheduler` which sits on top of the main thread, making the update of the UI possible.
 
 - `Schedulers` are NOT `threads` and they DON'T have a one-to-one relationship with threads.
 */

let fruit = Observable<String>.create { observer in
    observer.onNext("[apple]")
    sleep(2)
    observer.onNext("[pineapple]")
    sleep(2)
    observer.onNext("[strawberry]")
    
    return Disposables.create()
}

/*
 A common pattern which uses a background process to retrieve data from a server and process the data received, only switching to the MainScheduler to process the final event and display the data in the user interface.
 */
fruit
    .subscribeOn(globalScheduler) // The main observable is processing and generating events on the background threads
    .dump()
    .observeOn(MainScheduler.instance)
    .dumpingSubscription()
    .disposed(by: bag)

let animalsThread = Thread() {
    sleep(3)
    animal.onNext("[cat]")
    sleep(3)
    animal.onNext("[tiger]")
    sleep(3)
    animal.onNext("[fox]")
    sleep(3)
    animal.onNext("[leopard]")
}

animalsThread.name = "Animals Thread"
animalsThread.start()

// a minor hack that prevents Terminal from terminating once all operations hace completed on the main thread, which would kill the global scheduler and observable.
RunLoop.main.run(until: Date(timeIntervalSinceNow: 13))


/*:
 - Use `subsribeOn()` to change on which scheduler the observable "computation" code runs - the code taht is emitting the observable

 - Use `observeOn()` to change where the observer performs the code of the operations

 - HOT observable
    - one that doesn't have any side-effect during subscription, but has its own context in which evetns are generated and RxSwift can't control it.
    - shared
    - NO SIDE EFFECT

 - a COLD observable
    - in contrast doesn't produce any elements before any observers subscribes to it. Effectively means that it doesn't have its own context until, upon subscription, it creates some context and starts producing elements
    - not shared
    - has SIDE EFFECT - fire a request to the server, edit the local database, write to the file system...

 - Serial scheduler, Rx will do computations serially. For a serial dispatch queue, schedulers will also be able to perform their own optimizations underneath

 - Concurrent scheduler, Rx will try running code simultaneously, but `observeOn()` will preserve the sequence in which tasks need to be executed, and ensure that your subscription code ends up on the correct scheduler.
 
 - MainScheduler sits on top of the main thread. Used to process changes on the UI and perform other high-priority tasks. Additionally, if you perform side effects that update the UI, you must switch to the MainScheduler to guarentee those updates make it to the screen.
 
 - `SerialDispatchQueueScheduler` manages to abstract the work on SERIAL `DispatchQueue`.
 
 - `ConcurrentDispatchQueueScheduler` also manages to abstract work on a `DispatchQueue`
    - This kind of  of scheduler isn't optimized when using `observeOn()` so remember to account for that when deciding which kind of scheduler to use.
 
 - `OperationQueueScheduler` is similar to `ConcurrentDispatchQueueScheduler` but instead of abstracting the work over a `DispatchQueue`, it performs the job over an `NSOperationQueue` which provides more control over the concurrent jobs that is running. Capable of fine-tuning the max number of concurrent jobs.
 
 - `TestScheduler` is a special kind of scheduler. Part of `RxTest` library.
 
 
 
 */

