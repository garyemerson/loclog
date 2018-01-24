//
//  ViewController.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 1/15/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import UIKit
import CoreLocation

struct PropertyKey {
    static let datetime = "datetime"
    static let msg = "msg"
}

enum LogType {
    case Location
    case App
}

class ViewController: UIViewController, CLLocationManagerDelegate, UITextViewDelegate {
    //MARK: Properties
    @IBOutlet weak var locationMsg: UITextView!
    @IBOutlet weak var recentLogs: UITextView!
    @IBOutlet weak var currentLogLabel: UILabel!
    
    var numUpdates = 0
    var locManager = CLLocationManager()
    var region: CLCircularRegion? = nil
    var currLog = LogType.Location
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locManager.delegate = self
        locationMsg.delegate = self
        
//        locManager.requestWhenInUseAuthorization()
        locManager.requestAlwaysAuthorization()
//        locManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: 2)
        locManager.allowsBackgroundLocationUpdates = true
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        locManager.distanceFilter = kCLDistanceFilterNone
        
        reloadRecentLogView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        reloadRecentLogView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: Actions
    @IBAction func clearLogs(_ sender: UIButton) {
        LogEntry.saveLogs(logs: [LogEntry](), url: LogEntry.LocationLogsURL)
        LogEntry.saveLogs(logs: [LogEntry](), url: LogEntry.AppLogsURL)
        reloadRecentLogView()
    }
    @IBAction func refresh(_ sender: UIButton) {
        if let r = region {
            locManager.requestState(for: r)
            locationMsg.text = [
                    String(format: "region center: %f, %f", r.center.latitude, r.center.longitude),
                    String(format: "region radius: %f", r.radius)]
                .joined(separator: "\n")
        }
        reloadRecentLogView()
    }
    @IBAction func switchLogs(_ sender: UIButton) {
        if currLog == LogType.Location {
            currLog = LogType.App
            reloadRecentLogView()
            sender.contentMode = UIViewContentMode.right
            sender.setTitle("View Location Logs", for: UIControlState.normal)
            sender.sizeToFit()
            sender.frame.origin.x = sender.frame.origin.x - 31
            currentLogLabel.text = "App Logs"
        } else {
            currLog = LogType.Location
            reloadRecentLogView()
            sender.setTitle("View App Logs", for: UIControlState.normal)
            sender.sizeToFit()
            sender.frame.origin.x = sender.frame.origin.x + 31
            currentLogLabel.text = "Location Logs"
        }
    }
    
    func reloadRecentLogView() {
        let maybeLogs: [LogEntry]?
        if currLog == LogType.Location {
            maybeLogs = LogEntry.loadLogs(url: LogEntry.LocationLogsURL)
        } else {
            maybeLogs = LogEntry.loadLogs(url: LogEntry.AppLogsURL)
        }
        
        if let logs = maybeLogs {
            let dateFmt = DateFormatter()
            dateFmt.locale = Locale(identifier: "en_US")
            dateFmt.setLocalizedDateFormatFromTemplate("HH:mm:ss")
            
            let recent: ArraySlice = logs.dropFirst(0)//max(0, logs.count - 12))
            let s = recent
                .map({ dateFmt.string(from: $0.timeLogged) + " " + $0.msg })
                .joined(separator: "\n")
            recentLogs.text = s
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty {
            numUpdates += 1
            debugPrint("received location update", numUpdates)
            let coord = locations[0].coordinate
//            locationMsg.text = [
//                String(format: "%f, %f", coord.latitude, coord.longitude),
//                String(format: "(%f x %f)", locations[0].horizontalAccuracy, locations[0].verticalAccuracy),
//                String(describing: Date())].joined(separator: "\n")
            
            region = CLCircularRegion(center: coord, radius: 100, identifier: "foobar")
            locationMsg.text = [
                String(format: "region center: %f, %f", region!.center.latitude, region!.center.longitude),
                String(format: "region radius: %f", region!.radius)]
                .joined(separator: "\n")
            locManager.startMonitoring(for: region!)
            
            LogEntry.appendLog(msg: "added loc", url: LogEntry.LocationLogsURL)
            reloadRecentLogView()
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        debugPrint("error: ", error.localizedDescription)
        locationMsg.text = "error: " + error.localizedDescription
    }
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        debugPrint("defer error: ", error.debugDescription)
        locationMsg.text = "error"
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        debugPrint("auth status is", status)
        if status == CLAuthorizationStatus.authorizedAlways {
            locManager.requestLocation()
        }
    }
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        debugPrint("monitor error: ", error.localizedDescription)
        locationMsg.text = "error"
    }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        debugPrint("exited region")
        LogEntry.appendLog(msg: "exited region", url: LogEntry.LocationLogsURL)
        reloadRecentLogView()
        locManager.requestLocation()
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        debugPrint("entered region")
        LogEntry.appendLog(msg: "entered region", url: LogEntry.LocationLogsURL)
        reloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        LogEntry.appendLog(msg: "region state is " + String(describing: state.rawValue), url: LogEntry.LocationLogsURL)
        reloadRecentLogView()
    }
}

