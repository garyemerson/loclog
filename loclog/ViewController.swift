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
    @IBOutlet weak var regionMsg: UITextView!
    @IBOutlet weak var recentLogs: UITextView!
    @IBOutlet weak var currentLogLabel: UILabel!
    
    var locManager = CLLocationManager()
    var region: CLCircularRegion? = nil
    var region2: CLCircularRegion? = nil
    var region3: CLCircularRegion? = nil
    var currLog = LogType.App
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locManager.delegate = self
        regionMsg.delegate = self
        
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
        LogEntry.saveLogs(logs: [LogEntry](), url: LogEntry.AppLogsURL)
        reloadRecentLogView()
    }
    @IBAction func refresh(_ sender: UIButton) {
        if let r = region {
            locManager.requestState(for: r)
            regionMsg.text = getRegionStr()
        }
        reloadRecentLogView()
    }
    func getRegionStr() -> String {
        return [
            "region \(region!.identifier)",
            String(format: "center: %f, %f", (region?.center.latitude)!, (region?.center.longitude)!),
            String(format: "radius: %f", (region?.radius)!),
            "",
            "region \(region2!.identifier)",
            String(format: "center: %f, %f", (region2?.center.latitude)!, (region2?.center.longitude)!),
            String(format: "radius: %f", (region2?.radius)!),
            "",
            "region \(region3!.identifier)",
            String(format: "center: %f, %f", (region3?.center.latitude)!, (region3?.center.longitude)!),
            String(format: "radius: %f", (region3?.radius)!)]
        .joined(separator: "\n")
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
        if currLog == LogType.App {
            maybeLogs = LogEntry.loadLogs(url: LogEntry.AppLogsURL)
        } else {
            maybeLogs = []
        }
        
        if let logs = maybeLogs {
            let dateFmt = DateFormatter()
            dateFmt.locale = Locale(identifier: "en_US")
            dateFmt.setLocalizedDateFormatFromTemplate("yyyy-MM-dd - HH:mm:ss")
            
            let recent: ArraySlice = logs.dropFirst(0)//max(0, logs.count - 12))
            let s = recent
                .reversed()
                .map({ "[\(dateFmt.string(from: $0.timeLogged))] \($0.msg)" })
                .joined(separator: "\n")
            recentLogs.text = s
        }
    }
    func saveLocationsToDb(locatoins: [CLLocation]) {
        LogEntry.log(msg: "saving \(locatoins.count) location(s) to db", url: LogEntry.AppLogsURL)
        if (locatoins.count > 0) {
//            regionMsg.text = "running query..."
            
            // TODO: perhaps batch dbs calls to something like 1000 locations a batch so a single query
            // doesn't take very long. This minimize the harm done if a query gets cut off bc then hopefully
            // at least some queries before it could finish.
            DispatchQueue.global(qos: .background).async {
                let query =
                    "insert into locations (date,latitude,longitude,altitude,horizontal_accuracy,vertical_accuracy,course,speed,floor)\n" +
                    "values\n" +
                    locatoins.map({
                        """
                        ('\($0.timestamp)', \($0.coordinate.latitude), \($0.coordinate.longitude),
                        \($0.altitude), \($0.horizontalAccuracy), \($0.verticalAccuracy), \($0.course),
                        \($0.speed), \($0.floor?.description ?? "NULL"))
                        """
                    })
                    .joined(separator: ",\n");

                let result = exec_query(query).description
                DispatchQueue.main.async {
                    LogEntry.log(msg: "db save result is \(result)", url: LogEntry.AppLogsURL)
                    self.reloadRecentLogView()
                }
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty {
            let coord = locations[0].coordinate
            // locationMsg.text = [
            //    String(format: "%f, %f", coord.latitude, coord.longitude),
            //    String(format: "(%f x %f)", locations[0].horizontalAccuracy, locations[0].verticalAccuracy),
            //    String(describing: Date())].joined(separator: "\n")
            
            region = CLCircularRegion(center: coord, radius: 100, identifier: "foobar")
            region2 = CLCircularRegion(center: coord, radius: 1000, identifier: "foobar2")
            region3 = CLCircularRegion(center: coord, radius: 10000, identifier: "foobar3")
            regionMsg.text = getRegionStr()
            locManager.startMonitoring(for: region!)
            locManager.startMonitoring(for: region2!)
            locManager.startMonitoring(for: region3!)
            
            // TODO: Mark log entries as "saved to db" only when successfully save. That way if
            // there's a failure then we can retry all unsaved entries.
            saveLocationsToDb(locatoins: locations)
            reloadRecentLogView()
        }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LogEntry.log(msg: "error: \(error.localizedDescription)", url: LogEntry.AppLogsURL)
        regionMsg.text = "error: " + error.localizedDescription
        reloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        LogEntry.log(msg: "defer error: \(error.debugDescription)", url: LogEntry.AppLogsURL)
        regionMsg.text = "error"
        reloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        LogEntry.log(msg: "auth status is \(authToStr(status: status))", url: LogEntry.AppLogsURL)
        if status == CLAuthorizationStatus.authorizedAlways {
            locManager.requestLocation()
        }
        reloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        LogEntry.log(
            msg: "monitor error for region \(region?.identifier ?? "<none>"): \(error.localizedDescription)",
            url: LogEntry.AppLogsURL)
        regionMsg.text = "error"
        reloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        LogEntry.log(msg: "exited region \(region.identifier)", url: LogEntry.AppLogsURL)
        reloadRecentLogView()
        locManager.requestLocation()
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        LogEntry.log(msg: "entered region \(region.identifier)", url: LogEntry.AppLogsURL)
        reloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        LogEntry.log(msg: "region \(region.identifier) state is \(stateToStr(state: state))", url: LogEntry.AppLogsURL)
        reloadRecentLogView()
    }
    func authToStr(status: CLAuthorizationStatus) -> String {
        switch (status) {
        case CLAuthorizationStatus.notDetermined:
            return "notDetermined"
            
        case CLAuthorizationStatus.restricted:
            return "restricted"
            
        case CLAuthorizationStatus.denied:
            return "denied"
            
        case CLAuthorizationStatus.authorizedAlways:
            return "authorizedAlways"
            
        case CLAuthorizationStatus.authorizedWhenInUse:
            return "authorizedWhenInUse"
        }
    }
    func stateToStr(state: CLRegionState) -> String {
        switch (state) {
        case CLRegionState.unknown:
            return "unknown"
        case CLRegionState.inside:
            return "inside"
        case CLRegionState.outside:
            return "outside"
        }
    }
}

