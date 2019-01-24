//: Please build the scheme 'RxSwiftPlayground' first
import RxSwift
import RxSwiftExt

example(of: "toArray") {
    let disposeBag = DisposeBag()
    
    // Create an observable of letters
    Observable.of("A", "B", "C")
        .toArray() // Use `toArray()` to transform the elements in an array
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

example(of: "map") {
    let disposeBag = DisposeBag()
    
    let formatter = NumberFormatter()
    formatter.numberStyle = .spellOut
    
    // Create an observabel of NSNumbers so that you don't have to convert integers when using the formatter in the next step
    Observable<NSNumber>.of(123, 4, 56)
        // Use `map{...}` by passing a closure that gets and returns the result of using the formatter to return the number's spelled out string or an empty string if that operation returns nil
        .map {
            formatter.string(from: $0) ?? ""
        }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

example(of: "enumerated and map") {
    let disposeBag = DisposeBag()
    
    Observable.of(1, 2, 3, 4, 5, 6)
        // use `.enumerated` to produce tuple pairs of each element and its index
        .enumerated()
        // use `map` and decompose the tuple into individual values
        .map { index, integer in
            index > 2 ? integer * 2 : integer
        }
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
}

struct Student {
    var score: BehaviorSubject<Int>
}

example(of: "flatMap") {
    let disposeBag = DisposeBag()
    
    // Created two instances of Student - ryan and charlotte
    let ryan = Student(score: BehaviorSubject(value: 80))
    let charlotte  = Student(score: BehaviorSubject(value: 90))
    
    // Created the source `Subject` of type Student
    let student = PublishSubject<Student>()
    
    student
        // Used `flatMap` to reach into the student subject and access its score. No modifications here, simply passing
        .flatMap {
            $0.score
        }
        // Print out .next event
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
    
    student.onNext(ryan)
    ryan.score.onNext(85)
    student.onNext(charlotte)
    ryan.score.onNext(95)
    charlotte.score.onNext(100)
}

example(of: "flatMapLatest") {
    let disposeBag = DisposeBag()
    
    let ryan = Student(score: BehaviorSubject(value: 80))
    let charlotte  = Student(score: BehaviorSubject(value: 90))
    
    let student = PublishSubject<Student>()
    
    student
        // Used `flatMap` to reach into the student subject and access its score. No modifications here, simply passing
        .flatMapLatest {
            $0.score
        }
        // Print out .next event
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
    
    student.onNext(ryan)
    ryan.score.onNext(85)
    student.onNext(charlotte)
    // Changing the ryan's score here will results in no effect becasue `flatMapLatest` has already switched to the latest observable - charlotte.
    ryan.score.onNext(95)
    charlotte.score.onNext(100)
}

/*:
 Using `materialize()` operator, we can wrap each event emiited by an observable in an observable
 */
example(of: "materialize and dematerialize") {
    // Creates an error type
    enum MyError: Error {
        case anError
    }
    
    let disposeBag = DisposeBag()
    
    let ryan = Student(score: BehaviorSubject(value: 80))
    let charlotte  = Student(score: BehaviorSubject(value: 90))
    
    let student = PublishSubject<Student>()
    
    // With the addition of `materialize()`, type of `studentScore` has become `Observable<Event<Int>> instead of `Observable<Int>`
    let studentScore = student
        .flatMapLatest {
            $0.score.materialize()
        }
    
    studentScore
        // Print and filter out error
        .filter {
            guard $0.error == nil else {
                print($0.error!)
                return false
            }
            return true
        }
        .dematerialize() // transform the materialized observable - `Event` - back to original form - `Element`
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
    
    // adding score, error, score into the student
    student.onNext(ryan)
    ryan.score.onNext(85)
    ryan.score.onError(MyError.anError)
    ryan.score.onNext(90)
    // add a second student onto the student observabel. since `flatMapLatest` was used, this will switch onto the two student and subscribe to her score instead.
    student.onNext(charlotte)
}
// ==========================================================================================
example(of: "Challenge 1") {
    let disposeBag = DisposeBag()
    
    let contacts = [
        "603-555-1212": "Florent",
        "212-555-1212": "Junior",
        "408-555-1212": "Marin",
        "617-555-1212": "Scott"
    ]
    
    let convert: (String) -> UInt? = { value in
        if let number = UInt(value),
            number < 10 {
            return number
        }
        
        let keyMap: [String: UInt] = [
            "abc": 2, "def": 3, "ghi": 4,
            "jkl": 5, "mno": 6, "pqrs": 7,
            "tuv": 8, "wxyz": 9
        ]
        
        let converted = keyMap
            .filter { $0.key.contains(value.lowercased()) }
            .map { $0.value }
            .first
        
        return converted
    }
    
    let format: ([UInt]) -> String = {
        var phone = $0.map(String.init).joined()
        
        phone.insert("-", at: phone.index(
            phone.startIndex,
            offsetBy: 3)
        )
        
        phone.insert("-", at: phone.index(
            phone.startIndex,
            offsetBy: 7)
        )
        
        return phone
    }
    
    let dial: (String) -> String = {
        if let contact = contacts[$0] {
            return "Dialing \(contact) (\($0))..."
        } else {
            return "Contact not found"
        }
    }
    
    let input = Variable<String>("")

    // Add your code here
    input.asObservable()
        .map(convert)
        .unwrap()
        .skipWhile { $0 == 0 }
        .take(10)
        .toArray()
        .map(format)
        .map(dial)
        .subscribe(onNext: {
            print($0)
        })
        .disposed(by: disposeBag)
    
    input.value = ""
    input.value = "0"
    input.value = "408"
    
    input.value = "6"
    input.value = ""
    input.value = "0"
    input.value = "3"
    
    "JKL1A1B".forEach {
        input.value = "\($0)"
    }
    
    input.value = "9"
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
