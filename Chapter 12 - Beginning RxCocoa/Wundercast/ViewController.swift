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

import UIKit
import RxSwift
import RxCocoa

// Uni-directional data flow between `ApiController` and `ViewController`: ApiController --Data--> ViewController

class ViewController: UIViewController {
    
    @IBOutlet weak var searchCityName: UITextField!
    @IBOutlet weak var tempLabel: UILabel!
    @IBOutlet weak var humidityLabel: UILabel!
    @IBOutlet weak var iconLabel: UILabel!
    @IBOutlet weak var cityNameLabel: UILabel!
    
    let bag = DisposeBag()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        style()
        
//        ApiController.shared.currentWeather(city: "RxCity")
//            .observeOn(MainScheduler.instance)
//            .subscribe(onNext: { data in
//                self.tempLabel.text = "\(data.temperature)°C"
//                self.iconLabel.text = data.icon
//                self.humidityLabel.text = "\(data.humidity)"
//                self.cityNameLabel.text = data.cityName
//            })
//            .disposed(by: bag)
        
        // Return a new observable with the data to display
        // Since `currentWeather` does not accept `nil` or empty values, we will filter it out
        
//        searchCityName.rx.text
//            .filter { ($0 ?? "").count > 0 }
//            .flatMap { text in
//                return ApiController.shared.currentWeather(city: text ?? "Error")
//                    // prevents the observable from being disposed when you receive an error from the API.
//                    .catchErrorJustReturn(ApiController.Weather.empty)
//            }
//            .observeOn(MainScheduler.instance)
//            .subscribe(onNext: { data in
//                self.tempLabel.text = "\(data.temperature)°C"
//                self.iconLabel.text = data.icon
//                self.humidityLabel.text = "\(data.humidity)"
//                self.cityNameLabel.text = data.cityName
//            })
//            .disposed(by: bag)
 
        
//        // Similar to above commented code; However, by utilizing `flatMapLatest`, the results are now reusable and transforms a single-use data source into a multi-use `Observable`.
//        let search = searchCityName.rx.text
//            .filter { ($0 ?? "").count > 0 }
//            .flatMapLatest{ text in
//                return ApiController.shared.currentWeather(city: text ?? "Error")
//                .catchErrorJustReturn(ApiController.Weather.empty)
//            }
//            .share(replay: 1)
//            .observeOn(MainScheduler.instance)
//
//        // Binds different pieces of the data to each label on the screen
//        search.map { "\($0.temperature) °C" }
//            .bind(to:tempLabel.rx.text)
//            .disposed(by: bag)
//
//        search.map { $0.icon }
//            .bind(to:iconLabel.rx.text)
//            .disposed(by: bag)
//
//        search.map { "\($0.humidity) %" }
//            .bind(to:humidityLabel.rx.text)
//            .disposed(by: bag)
//
//        search.map { $0.cityName }
//            .bind(to:cityNameLabel.rx.text)
//            .disposed(by: bag)
        
        
       // let search = searchCityName.rx.text
        // In doing the following as oppose to the one above, we removed all unnecssary request query by simply sending out request only when the user hits the "Search" button. Code is now controlled at compile time by Traits.
        let search = searchCityName.rx.controlEvent(.editingDidEndOnExit)
            .asObservable()
            .map{ self.searchCityName.text }
            .filter { ($0 ?? "").count > 0}
            .flatMapLatest { text in
                return ApiController.shared.currentWeather(city: text ?? "Error")
                    .catchErrorJustReturn(ApiController.Weather.empty)
            }
            // Converts the observable into a `Driver`. `onErrorJustReturn` parameter specifies a default value to be used in case the observable errors out; eliminating the possiblility for the driver itself to emit an error.
            .asDriver(onErrorJustReturn: ApiController.Weather.empty)
        
        // Unlike the observables, use `.drive` instead of `bind(to:)`
        search.map { "\($0.temperature) °C" }
            .drive(tempLabel.rx.text)
            .disposed(by: bag)
        
        search.map { $0.icon }
            .drive(iconLabel.rx.text)
            .disposed(by: bag)
        
        search.map { "\($0.humidity) %" }
            .drive(humidityLabel.rx.text)
            .disposed(by: bag)
        
        search.map { $0.cityName  }
            .drive(cityNameLabel.rx.text)
            .disposed(by: bag)
        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        Appearance.applyBottomLine(to: searchCityName)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Style
    
    private func style() {
        view.backgroundColor = UIColor.aztec
        searchCityName.textColor = UIColor.ufoGreen
        tempLabel.textColor = UIColor.cream
        humidityLabel.textColor = UIColor.cream
        iconLabel.textColor = UIColor.cream
        cityNameLabel.textColor = UIColor.cream
    }
}

