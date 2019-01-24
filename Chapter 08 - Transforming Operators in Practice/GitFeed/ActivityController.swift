/*
 * Copyright (c) 2016-present Razeware LLC
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

import UIKit
import RxSwift
import RxCocoa
import Kingfisher

class ActivityController: UITableViewController {
    
    private let repo = "ReactiveX/RxSwift"
    
    private let events = Variable<[Event]>([])
    private let bag = DisposeBag()
    
    private let eventsFileURL = cachedFileURL("events.plist")
    
    // used to store a string of Date/Time which is the last-modified time.
    // this information will be gathered from and send back to the server so that only unfetched events are retrieved.
    private let modifiedFileURL = cachedFileURL("modified.txt")
    private let lastModified = Variable<NSString?>(nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = repo
        
        self.refreshControl = UIRefreshControl()
        let refreshControl = self.refreshControl!
        
        refreshControl.backgroundColor = UIColor(white: 0.98, alpha: 1.0)
        refreshControl.tintColor = UIColor.darkGray
        refreshControl.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        
        // first create an NSArray by using `init(contentsOf:)` which attempts to load list of object from a `.plist` file and cast it as Array<[String: Any]>
        let eventsArray = (NSArray(contentsOf: eventsFileURL) as? [[String: Any]]) ?? []
        // converts the JSON to `Event` objects by using `compactMap()`
        events.value = eventsArray.compactMap(Event.init)
        
        // if a value was previously stored `NSString(contentsOf: usedEncoding:)` will create an NSString with the text; otherwise, it'll return a nil value
        lastModified.value = try? NSString(contentsOf: modifiedFileURL, usedEncoding: nil)
        
        refresh()
    }
    
    @objc func refresh() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let strongSelf = self else { return }
            strongSelf.fetchEvents(repo: strongSelf.repo)
        }
    }
    
    func fetchEvents(repo: String) {
        // PROCESSING INPUT: String -map-> URL -map-> URLRequest -flatMap-> Response
        let response = Observable.from([repo])
            .map { urlString -> URL in
                return URL(string: "http://api.github.com/repos/\(urlString)/events")!
            }
            .map { [weak self] url -> URLRequest in
                // if `lastModified` contains a value, add that value as a "Last-Modified" header to the request
                // informs the server that we aren't interested in any events older than the header date
                var request = URLRequest(url: url)
                if let modifiedHeader = self?.lastModified.value {
                    request.addValue(modifiedHeader as String, forHTTPHeaderField: "Last-Modified")
                }
                return request
            }
            .flatMap { request -> Observable<(response: HTTPURLResponse, data: Data)> in
                // URLSession.shared.rx.response(request:) sensds the request to the server and upon receiving the response, emits a `.next` event ONCE with the returned data, and then completes.
                // In this situation, if the observable completes and then you subscribe to it again, it will create a new subscription and will fire another identical request to the server.
                // `share(replay: scope:)` keeps a buffer of the last `replay` emitted elements and feeds them to any newly subscribed observer.
                // `.whileConnected` will buffer elements up to the point where it has no more subscribers
                // `.forever` will keep the buffered elements forever - costs memory.
                return URLSession.shared.rx.response(request: request)
            }
            .share(replay: 1, scope: .whileConnected)
        
        // PROCESSING OUTPUT:
        response
            // filter out any error resposne and only let through responses having a status code between 200 and 300, which is all the success codes
            // `~=` when used with a range on its left side, checks if the range includes the value on its right side.
            .filter { response, _ in
                return 200..<300 ~=  response.statusCode
            }
            // discard the response object and take only the response data. return an `Array<[String: Any]>` which is what an array of JSON objects looks like. used `JSONSerializtion` to try to decode the response data and return the result -> if failed, returns an empty array.
            .map { _, data -> [[String: Any]] in
                guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                    let result = jsonObject as? [[String: Any]] else {
                        return []
                }
                return result
            }
            // filter out any responses that do not contain any even objects
            .filter { objects in
                return objects.count > 0
            }
            // takes in a [[String: Any]] parameter and outputs an [Event] result by calling map on the array itself and transforming its elements one-by-one.
            // the outter `.map{...}` is a method on an `Observable<Array<[String: Any]>>` instance and is acting asynchroniouslyon each emitted element
            // the inner `.map()` is a method on an Array, which synchronously iterate over the array elements and converts them using `Event.init`
            .map { objects in
                // any `Event.init` calls will return nil and `compactMap()` on those objects will remove any nil values, so we only have Observables that returns an array of Event objects (non-optional)
                // Note: replaced the deprecated method `flatMap()` to `compactMap()` to only contain non-nil elements
                return objects.compactMap(Event.init)
            }
            .subscribe(onNext: { [weak self] newEvents in
                self?.processEvents(newEvents)
            })
            .disposed(by: bag)
        
        // second subscription
        response
            .filter { response, _ in
                return 200..<400 ~= response.statusCode
            }
            .flatMap { response, _ -> Observable<NSString> in
                // use `guard` to check if the response contains HTTP header by the name of "Last-Modified" whose value can be cast to an `NSString` -> return `Observable` with element if possible, else empty
                guard let value = response.allHeaderFields["Last-Modified"] as? NSString else {
                    return Observable.empty()
                }
                return Observable.just(value)
            }
            .subscribe(onNext: { [weak self] modifiedHeader in
                guard let strongSelf = self else { return }
                // update `lastModified.value` with the latest date and then call
                strongSelf.lastModified.value = modifiedHeader
                try? modifiedHeader.write(to: strongSelf.modifiedFileURL, atomically: true, encoding: String.Encoding.utf8.rawValue)
            })
            .disposed(by: bag)
    }
    
    func processEvents(_ newEvents: [Event]) {
        var updatedEvents = newEvents + events.value
        // Append the newly fetched events to the list in `events.value` while capping the list to 50 objects to show only the latest activity in the table view.
        if updatedEvents.count > 50 {
            updatedEvents = Array<Event>(updatedEvents.prefix(upTo: 50))
        }
        events.value = updatedEvents
        
        // though not recommended, use GCD to switch to the main thread and update the table
        DispatchQueue.main.async {
            // `endRefreshing` hides the refreshControl after pulling it down to refresh
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        }
        
        //convert `updatedEvents` to JSON objects and store tham in `eventsArray` which is an instance of NSArray
        let eventsArray = updatedEvents.map { $0.dictionary } as NSArray
        // write will create or overwrite an existing file at the given URL
        eventsArray.write(to: eventsFileURL, atomically: true)
    }
    
    // MARK: - Table Data Source
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return events.value.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let event = events.value[indexPath.row]
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = event.name
        cell.detailTextLabel?.text = event.repo + ", " + event.action.replacingOccurrences(of: "Event", with: "").lowercased()
        cell.imageView?.kf.setImage(with: event.imageUrl, placeholder: UIImage(named: "blank-avatar"))
        return cell
    }
}

func cachedFileURL(_ filename: String) -> URL {
    return FileManager.default
        .urls(for: .cachesDirectory, in: .allDomainsMask)
        .first!
        .appendingPathComponent(filename)
}
