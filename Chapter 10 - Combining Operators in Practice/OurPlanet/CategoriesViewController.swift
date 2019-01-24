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

import UIKit
import RxSwift
import RxCocoa

class CategoriesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    let categories = Variable<[EOCategory]>([])
    let disposeBag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //subscribe to the VARIABLE to update the table view
        categories
            .asObservable()
            .subscribe(onNext: { [weak self] _ in
                // ensures the table view update occurs on the main thread
                DispatchQueue.main.async {
                    self?.tableView?.reloadData()
                }
            })
            .disposed(by: disposeBag)
        
        startDownload()
    }
    
    func startDownload() {
        let eoCategories = EONET.categories
        // first, get all the categories, then call `flatMap`to transform them into an observable emitting one observable of events for each category.
        let downloadedEvents = eoCategories.flatMap { categories in
            return Observable.from(categories.map { category in
                EONET.events(forLast: 360, category: category)
            })
        }
        // merge all these observables into a single stream of event array
        .merge(maxConcurrent: 2)
        
//        let updatedCategories = Observable
//            // used `combineLatest(_:_:resultSelector:)` to combine the downloaded categories with the downloaded events and build an updated category list with events added.
//            // closure gets called with the latest categories array, from the `eoCategories` observable, and the latest events array, from the `downloadedEvents` observable.
//            // produce an array of categories with their events
//            .combineLatest(eoCategories, downloadedEvents) { (categories, events) -> [EOCategory] in
//                return categories.map { category in
//                    var cate = category
//                    cate.events = events.filter {
//                        $0.categories.contains(category.id)
//                    }
//                    return cate
//                }
//            }

        let updatedCategories = eoCategories.flatMap { categories in
            // for every element emitted by its source observable, scan calls the closure and emits the accumulated value
            // in this case, the accumulated value is the updated list of categories.
            // hence, everytime a new gruop of events arrives, `scan` emits a category update.
            downloadedEvents.scan(categories){ updated, events in
                return updated.map { category in
                    let eventsForCategory = EONET.filteredEvents(events: events, forCategory: category)
                    if !eventsForCategory.isEmpty {
                        var cate = category
                        cate.events += eventsForCategory
                        return cate
                    }
                    return category
                }
            }
        }
        
        eoCategories
            // bind items from the `eoCategories` observable and items from the `updatedCategories` observable.
            .concat(updatedCategories)
            .bind(to: categories)
            .disposed(by: disposeBag)
        
//        eoCategories
//            // connects a source observable (EONET.categories) to an observer (categories VARIABLE)
//            .bind(to: categories)
//            .disposed(by: disposeBag)
    }
    
    // MARK: UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // get the number of table view items by pulling the current contents from the `categories` variable.
        return categories.value.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "categoryCell")!
        let category = categories.value[indexPath.row]
        cell.textLabel?.text = "\(category.name) (\(category.events.count))"
        cell.accessoryType = (category.events.count > 0) ? .disclosureIndicator : .none
        cell.detailTextLabel?.text = category.description
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let category = categories.value[indexPath.row]
        if !category.events.isEmpty {
            let eventsController = storyboard!.instantiateViewController(withIdentifier: "events") as! EventsViewController
            eventsController.title = category.name
            eventsController.events.value = category.events
            navigationController!.pushViewController(eventsController, animated: true)
        }
        tableView.deselectRow(at: indexPath, animated: true)
    }
    
}

