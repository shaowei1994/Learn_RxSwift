//: Please build the scheme 'RxSwiftPlayground' first

import RxSwift
import PlaygroundSupport

// When working with asynchronous code, enable indefinite execution to allow execution to continue after the end of the playground’s top-level code is reached. This, in turn, gives threads and callbacks time to execute.
PlaygroundPage.current.needsIndefiniteExecution = true

/*:
 - `startWith(_:)` operator prefixes an observable sequence with the given initial value which must be matching type with the observable elements
 - simple variant of the more general `concat` family of operators which chains two sequences.
 */
example(of: "startWith") {
    // Create a sequence of numbers
    let numbers = Observable.of(2, 3, 4)
    // Create a sequence with the value 1, then continue with the original sequence of numbers
    let observable = numbers.startWith(1)
    observable
        .subscribe(onNext: { value in
            print(value)
        })
}

// Class Method of `concat`
example(of: "Observable.concat") {
    let first = Observable.of(3, 4, 5)
    let second = Observable.of(0, 1, 2)
    
    let observable = Observable.concat([second, first])
    observable.subscribe(onNext: { print($0) })
    
}


// Instance Method of `concat`
example(of: "concat") {
    let germanCities = Observable.of("Berlin", "Munich", "Frankfurt")
    let spanishCities = Observable.of("Madrid", "Barcelona", "Valencia")
    
    germanCities.concat(spanishCities)
        .subscribe(onNext: {
            print($0)
        })
}

// `concatMap(_:)` guarantees that each sequence produced by the closure will run to completion before the next is subscribed to.
// handy way to guarantee sequential order
example(of: "concatMap") {
    let sequences = [
        "Germany": Observable.of("Berlin", "Munich", "Frankfurt"),
        "Spain": Observable.of("Madrid", "Barcelona", "Valencia")
    ]
    
    // Has a sequence emit country names whcih are map to sequences emitting city names for this country
    let observable = Observable.of("Germany", "Spain")
        .concatMap { country in
            sequences[country] ?? .empty()
        }
    
    // Output the full sequence for a given country before starting to consider the next one.
    _ = observable.subscribe(onNext: {
        print($0)
    })
}

/*:
 - `merge()` completes after its source sequence AND all inner sequences have completed.
- The order in which the inner sequences complete is irrelevant
- Immediately relays the error then terminates once any of the sequences emit an error.
 - To limit the number of sequences subscribed to at once, we can use `merge(maxConcurrent:)`
*/
example(of: "merge") {
    let bag = DisposeBag()
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    
    // Create a source observable of observables
    let source = Observable.of(left.asObservable(), right.asObservable())
    
    // Create a merge observable from the two usbjects, as well as a subscription to print the values it emits
    let observable = source.merge()
    let disposable = observable
        .subscribe(onNext: { print($0) })
    
    var leftValues = ["Berlin", "Munich", "Frankfurt"]
    var rightValues = ["Madrid", "Barcelona", "Valencia"]
    
    repeat {
        if arc4random_uniform(2) == 0 {
            if !leftValues.isEmpty {
                left.onNext("Left: " + leftValues.removeFirst())
            } else if !rightValues.isEmpty {
                right.onNext("Right: " + rightValues.removeFirst())
            }
        }
    } while !rightValues.isEmpty || !leftValues.isEmpty
    
    disposable.disposed(by: bag)
}

/*:
 - Combine values from several sequences
 - Every time one of the inner (combined) sequences emits a value, it calls a closure you provide
 - You receive the last value from teach of the inner sequences.
 - Nothing will happen until each of the combined observables emits one value. After that, each time one emits a new value, the closure receives the LATEST value of each of the observable and produces its element
 - Creates an observable whose type is the closure return type - which is a good opportunity to swich to a new type alonside a chain of operators.
 - `combineLatest()` completes only when the last of its inner sequences completes. Before thatm it keeps sending combined values. If some sequences terminates, it uses the last value emitted to combine with new values from other sequences.
 */
example(of: "combineLatest") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    
    let observable = Observable.combineLatest(left, right) { lastLeft, lastRight in
        "\(lastLeft) \(lastRight)"
    }
    
    let disposable = observable.subscribe(onNext: { print($0) })
    print("> Sending a value to Left")
    left.onNext("Hello,")
    print("> Sending a value to Right")
    right.onNext("world")
    print("> Sending another value to Right")
    right.onNext("RxSwift")
    print("> Sending another value to Left")
    left.onNext("Have a good day,")
    
    // needs to dispose the subscription as we are working with infinite sequences
    disposable.dispose()
}

// A variant of `combineLatest()` which takes between two and eight observable sequences as parameters
example(of: "combine user choice and value") {
    let choice: Observable<DateFormatter.Style> = Observable.of(.short, .long)
    let dates = Observable.of(Date())
    
    let observable = Observable.combineLatest(choice, dates) { (format, when) -> String in
        let formatter = DateFormatter()
        formatter.dateStyle = format
        return formatter.string(from: when)
    }
    
    observable.subscribe(onNext: { print($0) })
}

// A final variant of the `combineLatest()` family which takes a collection of observables and a combining closure, which receives latest values in an array. Since it's a collection, all observables carry elements of the same type.
example(of: "combineLatest") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    
    let observable = Observable.combineLatest([left, right]) { strings in
        strings.joined(separator: " ")
    }
    
    let disposable = observable.subscribe(onNext: { print($0) })
    print("> Sending a value to Left")
    left.onNext("Hello,")
    print("> Sending a value to Right")
    right.onNext("world")
    print("> Sending another value to Right")
    right.onNext("RxSwift")
    print("> Sending another value to Left")
    left.onNext("Have a good day,")
    
    // needs to dispose the subscription as we are working with infinite sequences
    disposable.dispose()
}

example(of: "zip") {
    enum Weather {
        case cloudy
        case sunny
    }
    
    let left: Observable<Weather> = Observable.of(.sunny, .cloudy, .cloudy, .sunny)
    let right = Observable.of("Lisbon", "Copoenhagen", "London", "Madrid", "Vienna")
    
    // Subscribe to the observables provided then waited for each to emit a new value.
    // Closure is called once both new values are provided
    // "INDEX SEQUENCING" - If one of the inner observable completes (left completes with only 4 elements), `zip` completes as well. It does not wait for all of inner observables to finish.
    let observable = Observable.zip(left, right) { weather, city in
        return "It's \(weather) in \(city)"
    }
    observable.subscribe(onNext: { print($0) })
}

example(of: "withLatestFrom") {
    // Create two subjects simulating button presses and text field input. Since the button carries no real data, you can use `Void` as an element type
    let button = PublishSubject<Void>()
    let textField = PublishSubject<String>()
    
    // When `button` emits a value, ignore it but instead emit the latest value received from the simualted text field
     let observable = button.withLatestFrom(textField)
    _ = observable.subscribe(onNext: { print($0) })
    
    // Simulate successive inputs to the text field, which is done by the two successive button presses
    textField.onNext("Par")
    textField.onNext("Pari")
    textField.onNext("Paris")
    button.onNext(())
    button.onNext(())
}

/*:
 Note that `withLatestFrom(_:)` takes the data observable as a parameter, while `sample(_:) takes the trigger observable as a parameter.
 */
example(of: "sample") {
    // Create two subjects simulating button presses and text field input. Since the button carries no real data, you can use `Void` as an element type
    let button = PublishSubject<Void>()
    let textField = PublishSubject<String>()

    // Each time the trigger observable emits a value, `sample(_:) emits the latest value form the "other" observable, but only if it arrived since the last "tick". If no new data arrived, `sample(_:)` won't emit anything.
    // Could have acheived the same result by adding a `distinctUntilChanged()` to the `withLastFrom(_:)` observable.
    let observable = textField.sample(button)
    _ = observable.subscribe(onNext: { print($0) })
    
    // Simulate successive inputs to the text field, which is done by the two successive button presses
    textField.onNext("Par")
    textField.onNext("Pari")
    textField.onNext("Paris")
    button.onNext(())
    button.onNext(())
}

/*:
- The `amb(:_)` operator waits for either of left/right to emit an element, then unsubscribes from the "other" one. After that, it only relays elements from the first active observable.
- Can be practical such as connecting to redundant servers and sticking with the one that responds first
 */
example(of: "amb") {
    let left = PublishSubject<String>()
    let right = PublishSubject<String>()
    
    // Create an observable which resolves "ambiguity" between left and right.
    let observable = left.amb(right)
    let disposable = observable.subscribe(onNext: { print($0) })
    
    left.onNext("Lisbon")
    right.onNext("Copenhagen")
    left.onNext("London")
    left.onNext("Madrid")
    right.onNext("Vienna")
    
    disposable.dispose()
}

example(of: "switchLatest") {
    
    let one = PublishSubject<String>()
    let two = PublishSubject<String>()
    let three = PublishSubject<String>()
    
    let source = PublishSubject<Observable<String>>()
    
    let observable = source.switchLatest()
    let disposable = observable.subscribe(onNext: { print($0) })

    // Subscription will only print items from the latest sequence pushed to the `source` observable
    source.onNext(one)
    one.onNext("1) S1")
    two.onNext("1) S2")
    
    source.onNext(two)
    two.onNext("2) S2")
    one.onNext("2) S1")
    
    source.onNext(three)
    two.onNext("3) S2")
    one.onNext("3) S1")
    three.onNext("3) S3")
    
    source.onNext(one)
    one.onNext("1) S1")
    
    disposable.dispose()
}

example(of: "reduce") {
    let source = Observable.of(1, 3 ,5 ,7, 9)
    
    // Start with initial value "0" and each time the source observable emits an item, `reduce(_:_:)` calls the closure to produce new value.
    let observable = source.reduce(0, accumulator: +)
    let equivalentObservable = source.reduce(0, accumulator: { acc, value in
        return acc + value
    })
    observable.subscribe(onNext: { print($0) })
    equivalentObservable.subscribe(onNext: { print($0) })
    
    // Note that `reduce(_:_:)` produces its summary value IFF the source observable completes. Applying this operator to seqeunces that never complete won't emit anything.
}

/*:
 - You get one output per input value. This value is the running total accumulated by the closure.
 - Each time the source observableemits an element, `scan(_:accumulator:)` invokes your closure.
 - It passes the running value along with the new element, and the closure returns the new accumulated value
 */
example(of: "scan") {
    let source = Observable.of(1, 3, 5, 7, 9)
    
    let observable = source.scan(0, accumulator: +)
    observable.subscribe(onNext: { print($0) })
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
