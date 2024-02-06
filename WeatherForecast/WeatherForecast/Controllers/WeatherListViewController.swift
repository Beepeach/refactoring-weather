//
//  WeatherForecast - ViewController.swift
//  Created by yagom. 
//  Copyright © yagom. All rights reserved.
// 

import UIKit

class WeatherListViewController: UIViewController {
    private let weatherListView: WeatherListView = WeatherListView()
    private let weatherListUseCase: WeatherListUseCase
    private var weatherJSON: WeatherJSON?
    private let dateFormatter: DateFormatter
    private let imageChache: NSCache<NSString, UIImage> = NSCache()
    private var tempUnit: TemperatureUnit = .metric {
        didSet {
            navigationItem.rightBarButtonItem?.title = tempUnit.strategy.unitExpression
            refresh()
        }
    }
    
    override func loadView() {
        view = weatherListView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initialSetUp()
    }
    
    init(useCase: WeatherListUseCase, dateFormatter: DateFormatter) {
        self.weatherListUseCase = useCase
        self.dateFormatter = dateFormatter
        super.init(nibName: nil, bundle: nil)
    }
    
    convenience init() {
        self.init(useCase: DefaultWeatherListUseCase(),
                  dateFormatter: DateFormatterCreator.createKoreanDateFormatter())
    }
    
    required init?(coder: NSCoder) {
        self.weatherListUseCase = DefaultWeatherListUseCase()
        self.dateFormatter = DateFormatterCreator.createKoreanDateFormatter()
        super.init(coder: coder)
    }
}

extension WeatherListViewController {
    @objc private func changeTempUnit() {
        tempUnit = tempUnit.change()
    }
    
    @objc private func refresh() {
        let url: URL? = Bundle.main.url(forResource: "weather", withExtension: "json")
        weatherJSON = weatherListUseCase.fetchWeatherList(url: url)
        navigationItem.title = weatherJSON?.city.name
        weatherListView.reloadTableView()
        weatherListView.endRefreshControlRefreshing()
    }
    
    private func initialSetUp() {
        navigationItem.rightBarButtonItem =  UIBarButtonItem(title: tempUnit.strategy.unitExpression, image: nil, target: self, action: #selector(changeTempUnit))
        weatherListView.refreshControl.addTarget(self,
                                 action: #selector(refresh),
                                 for: .valueChanged)
        weatherListView.setTableViewDelegate(self)
        weatherListView.setTableViewDataSource(self)
    }
}


extension WeatherListViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        weatherJSON?.weatherForecast.count ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: UITableViewCell = tableView.dequeueReusableCell(withIdentifier: "WeatherCell", for: indexPath)
        
        guard let cell: WeatherTableViewCell = cell as? WeatherTableViewCell,
              let weatherForecastInfo = weatherJSON?.weatherForecast[indexPath.row] else {
            return cell
        }
        
        cell.weatherLabel.text = weatherForecastInfo.weather.main
        cell.descriptionLabel.text = weatherForecastInfo.weather.description
        cell.temperatureLabel.text = "\(tempUnit.strategy.convertTemperature(weatherForecastInfo.main.temp))"
        
        let date: Date = Date(timeIntervalSince1970: weatherForecastInfo.dt)
        cell.dateLabel.text = dateFormatter.string(from: date)
                
        let iconName: String = weatherForecastInfo.weather.icon         
        let urlString: String = "https://openweathermap.org/img/wn/\(iconName)@2x.png"
                
        if let image = imageChache.object(forKey: urlString as NSString) {
            cell.weatherIcon.image = image
            return cell
        }
        
        Task {
            guard let url: URL = URL(string: urlString),
                  let (data, _) = try? await URLSession.shared.data(from: url),
                  let image: UIImage = UIImage(data: data) else {
                return
            }
            
            imageChache.setObject(image, forKey: urlString as NSString)
            
            if indexPath == tableView.indexPath(for: cell) {
                cell.weatherIcon.image = image
            }
        }
        
        return cell
    }
}

extension WeatherListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let detailViewController: WeatherDetailViewController = WeatherDetailViewController()
        detailViewController.weatherForecastInfo = weatherJSON?.weatherForecast[indexPath.row]
        detailViewController.cityInfo = weatherJSON?.city
        detailViewController.tempUnit = tempUnit
        navigationController?.show(detailViewController, sender: self)
    }
}

