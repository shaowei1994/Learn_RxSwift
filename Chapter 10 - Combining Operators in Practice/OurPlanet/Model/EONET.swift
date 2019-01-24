/*
 * Copyright (c) 2016 Razeware LLC
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
import RxCocoa

class EONET {
    static let API = "https://eonet.sci.gsfc.nasa.gov/api/v2.1"
    static let categoriesEndpoint = "/categories"
    static let eventsEndpoint = "/events"
    
    static var ISODateReader: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
        return formatter
    }()
    
    // the `categories` observable created here is a singlton (static var).
    static var categories: Observable<[EOCategory]> = {
        // Request data from the `categories` endpoint
        return EONET.request(endpoint: categoriesEndpoint)
            .map { data in
                // Extract the `categories` array from the response
                let categories = data["categories"] as? [[String: Any]] ?? []
                // Map it to an array of `EOCategory` objects and sort them by name
                return categories
                    .compactMap(EOCategory.init)
                    .sorted { $0.name < $1.name }
            }
            // if a network error occurs at this stage, output an empty array
            .catchErrorJustReturn([])
            // all subscribers will get the same one
            // the first subscriber triggers the subscription to the `request` observable
            // the response maps to an array of categories
            // `share(replay:scope:)` relays all elements to the first subscriber
            // It then `replays` the last received element to any new subscriber, without re-request the data.
            //  acts like a cache.
            .share(replay: 1, scope: .forever)
    }()
    
    static func filteredEvents(events: [EOEvent], forCategory category: EOCategory) -> [EOEvent] {
        return events.filter { event in
            return event.categories.contains(category.id) &&
                !category.events.contains {
                    $0.id == event.id
            }
            }
            .sorted(by: EOEvent.compareDates)
    }
    
    static func request(endpoint: String, query: [String: Any] = [:]) -> Observable<[String: Any]> {
        do {
            
            guard let url = URL(string: API)?.appendingPathComponent(endpoint),
                var components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
                    throw EOError.invalidURL(endpoint)
            }
            
            components.queryItems = try query.compactMap { (key, value) in
                guard let v = value as? CustomStringConvertible else {
                    throw EOError.invalidParameter(key, value)
                }
                return URLQueryItem(name: key, value: v.description)
            }
            
            guard let finalURL = components.url else {
                throw EOError.invalidURL(endpoint)
            }
            
            let request = URLRequest(url: finalURL)
            
            // - `URLSession.rx.response` creates an observabel from the result of a request.
            // - When the data comes back, the code deserializes it to an object, then casts to a `[String: Any]` dictionary.
            return URLSession.shared.rx.response(request: request)
                .map{ _, data -> [String: Any] in
                    guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                        let result = jsonObject as? [String: Any] else {
                            throw EOError.invalidJSON(finalURL.absoluteString)
                    }
                    return result
            }
            
        } catch {
            return Observable.empty()
        }
    }
    
    fileprivate static func events(forLast days: Int, closed: Bool, endpoint: String) -> Observable<[EOEvent]> {
        return request(endpoint: endpoint, query: [
            "days": NSNumber(value: days),
            "status": (closed ? "closed" : "open")
        ])
        // maps the events array to an array of EOEvent objects
        .map { json in
            // error handling by using `guard` keyword
            guard let raw = json["events"] as? [[String: Any]] else {
                throw EOError.invalidJSON(endpoint)
            }
            // the `compactMap(_:)` here is the standard Swift API to turn dictionaries into an array of events
            return raw.compactMap(EOEvent.init)
        }
        .catchErrorJustReturn([])
    }
    
    static func events(forLast days: Int = 360, category: EOCategory) -> Observable<[EOEvent]> {
        let openEvents = events(forLast: days, closed: false, endpoint: category.endpoint)
        let closedEvents = events(forLast: days, closed: true, endpoint: category.endpoint)
        
        // OPTION 1 : download open events followed by closed events then concatenate them together
//        // `.concat(_:)` creates an observable that first runs its source observable (openEvents) to completion, then subscribes to `closedEvents`.
//        // if either of those errors out, it immediately relays the error and terminates
//        return openEvents.concat(closedEvents)
        
        // OPTION 2 : download open and closed events in parallel then merge them together
        // Create an observable of observables
        return Observable.of(openEvents, closedEvents)
            // `merge()` takes an observable of observables. It subscribes to each observables emitted by the source observable and relays all emitted elements
            .merge()
            // reduce the result to an array.
            // start with an empty array, and each time one of the observable delivers an array of events, the closure gets called, which then adds the new array to the existing array.
            // once complete, `reduce` emits a single value and completes
            .reduce([]) { running, new in
                running + new
            }
    }
}
