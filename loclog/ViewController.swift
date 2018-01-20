//
//  ViewController.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 1/15/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate {
    //MARK: Properties
    @IBOutlet weak var locationLabel: UILabel!
    var numPresses = 0
    let words = ["ba", "da ", "bing ", "ba", "da ", "boom"]
    let locManager = CLLocationManager()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
//        locationLabel.text = "foobar"
//        requestWhenInUseAuthorization
        locManager.requestWhenInUseAuthorization()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: Actions
    @IBAction func updateGarLocation(_ sender: UIButton) {
//        if numPresses == 0 {
//            locationLabel.text = words[0]
//        } else if numPresses < 6 {
//            locationLabel.text = locationLabel.text.unsafelyUnwrapped + words[numPresses]
//        }
//        numPresses += 1

        locationLabel.text = CLLocationManager.locationServicesEnabled() ?
            "enabled" : "disabled"
        locManager.desiredAccuracy = 1000
        locManager.delegate = self
        locManager.requestLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if locations.count > 0 {
            debugPrint("success")
            let coord = locations[0].coordinate
            locationLabel.text = coord.latitude.description + ", " + coord.longitude.description
        } else {
            debugPrint("empty")
            locationLabel.text = "empty"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint("error: ", error.localizedDescription)
        locationLabel.text = "error: " + error.localizedDescription
    }
    
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        debugPrint("error")
        locationLabel.text = "error"
    }
}

