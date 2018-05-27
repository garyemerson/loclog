//
//  ViewController.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 1/15/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, CLLocationManagerDelegate, UITextViewDelegate {
    //MARK: Properties
    @IBOutlet weak var regionMsg: UITextView!
    @IBOutlet weak var recentLogs: UITextView!
    @IBOutlet weak var currentLogLabel: UILabel!
    
    var locManager = CLLocationManager()
    var region: CLCircularRegion? = nil
    var region2: CLCircularRegion? = nil
    var region3: CLCircularRegion? = nil
    var region4: CLCircularRegion? = nil
    var currLog = LogType.App
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        locManager.delegate = self
        regionMsg.delegate = self
        
        locManager.requestAlwaysAuthorization()
        //locManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: 2)
        locManager.allowsBackgroundLocationUpdates = true
        locManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locManager.distanceFilter = kCLLocationAccuracyHundredMeters
        
        maybeReloadRecentLogView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        maybeReloadRecentLogView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: Actions
    @IBAction func clearLogs(_ sender: UIButton) {
        LogEntry.saveLogs(logs: [LogEntry](), url: LogEntry.AppLogsURL)
        maybeReloadRecentLogView()
    }
    @IBAction func refresh(_ sender: UIButton) {
        if let r = region {
            locManager.requestState(for: r)
            regionMsg.text = getRegionStr()
        }
        maybeReloadRecentLogView()
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
            maybeReloadRecentLogView()
            sender.contentMode = UIViewContentMode.right
            sender.setTitle("View Location Logs", for: UIControlState.normal)
            sender.sizeToFit()
            sender.frame.origin.x = sender.frame.origin.x - 31
            currentLogLabel.text = "App Logs"
        } else {
            currLog = LogType.Location
            maybeReloadRecentLogView()
            sender.setTitle("View App Logs", for: UIControlState.normal)
            sender.sizeToFit()
            sender.frame.origin.x = sender.frame.origin.x + 31
            currentLogLabel.text = "Location Logs"
        }
    }
    
    func maybeReloadRecentLogView() {
        if UIApplication.shared.applicationState != UIApplicationState.background {
            let maybeLogs: [LogEntry]?
            if currLog == LogType.App {
                maybeLogs = LogEntry.loadLogs(url: LogEntry.AppLogsURL)
            } else {
                maybeLogs = LogEntry.loadLogs(url: LogEntry.LocationLogsURL)
            }
            
            if let logs = maybeLogs {
                let dateFmt = DateFormatter()
                dateFmt.locale = Locale(identifier: "en_US")
                dateFmt.setLocalizedDateFormatFromTemplate("yyyy-MM-dd")
                
                let dateFmt2 = DateFormatter()
                dateFmt2.locale = Locale(identifier: "en_US")
                dateFmt2.setLocalizedDateFormatFromTemplate("HH:mm:ss")
                
                let recent: ArraySlice = logs.dropFirst(0)//max(0, logs.count - 12))
                let s: String = Dictionary(grouping: recent, by: { (e: LogEntry) in Calendar.current.startOfDay(for: e.timeLogged) })
                    .sorted(by: { $0.key > $1.key })
                    .map({
                        "--\(dateFmt.string(from: $0.key))--\n" +
                            $0.value
                                .sorted(by: { $0.timeLogged > $1.timeLogged })
                                .map({
                                    "[\(dateFmt2.string(from: $0.timeLogged))] \($0.msg)"
                                })
                                .joined(separator: "\n")
                    })
                    .joined(separator: "\n")
                recentLogs.text = s
            }
        }
    }
    func maybeUploadLocationsToDb() {
        let lastUpdate = LogEntry.loadLogs(url: LogEntry.LastUploadUrl).max(by: { $0.timeLogged < $1.timeLogged })
        if lastUpdate == nil || lastUpdate!.timeLogged.timeIntervalSinceNow < -(10 * 60) {
            let locations = LogEntry.loadLogs(url: LogEntry.LocationLogsURL)
            LogEntry.log(msg: "attempting upload of \(locations.count) location(s) to db", url: LogEntry.AppLogsURL)
            if (!locations.isEmpty) {
                // regionMsg.text = "running query..."
                
                // TODO: perhaps batch dbs calls to something like 1000 locations a batch so a single query
                // doesn't take very long. This minimize the harm done if a query gets cut off bc then hopefully
                // at least some queries before it could finish.
                DispatchQueue.global(qos: .background).async {
                    let query =
                        "insert into locations (date,latitude,longitude,altitude,horizontal_accuracy,vertical_accuracy,course,speed,floor)\n" +
                        "values\n" +
                        locations
                            .map({$0.msg})
                            .joined(separator: ",\n");

                    let result = exec_query(query)
                    LogEntry.saveLogs(logs: [], url: LogEntry.LocationLogsURL)
                    DispatchQueue.main.async {
                        if result == 0 {
                            LogEntry.log(msg: "db save succeeded", url: LogEntry.AppLogsURL)
                            LogEntry.saveLogs(logs: [LogEntry(timeLogged: Date(), msg: "")], url: LogEntry.LastUploadUrl)
                        } else {
                            LogEntry.log(msg: "db save failed with \(result.description)", url: LogEntry.AppLogsURL)
                        }
                        self.maybeReloadRecentLogView()
                    }
                }
            }
        } else {
            LogEntry.log(msg: "Recent last upload \(lastUpdate!.timeLogged.timeIntervalSinceNow) seconds ago, skipping", url: LogEntry.AppLogsURL)
            self.maybeReloadRecentLogView()
        }
    }
    
    func locationToStr(location: CLLocation) -> String {
        return
            """
            ('\(location.timestamp)', \(location.coordinate.latitude), \(location.coordinate.longitude),
            \(location.altitude), \(location.horizontalAccuracy), \(location.verticalAccuracy), \(location.course),
            \(location.speed), \(location.floor?.description ?? "NULL"))
            """
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty {
            LogEntry.log(
                msgs: locations.map(locationToStr),
                url: LogEntry.LocationLogsURL)
            
            let coord = locations.max(by: { $0.timestamp < $1.timestamp })!.coordinate
            // locationMsg.text = [
            //    String(format: "%f, %f", coord.latitude, coord.longitude),
            //    String(format: "(%f x %f)", locations[0].horizontalAccuracy, locations[0].verticalAccuracy),
            //    String(describing: Date())].joined(separator: "\n")
            
            LogEntry.log(msg: "creating new regions with center \(coord)", url: LogEntry.AppLogsURL)
            region = CLCircularRegion(center: coord, radius: 10, identifier: "foobar")
            region2 = CLCircularRegion(center: coord, radius: 100, identifier: "foobar2")
            region3 = CLCircularRegion(center: coord, radius: 1000, identifier: "foobar3")
            region4 = CLCircularRegion(center: coord, radius: 10000, identifier: "foobar4")
            regionMsg.text = getRegionStr()
            locManager.startMonitoring(for: region!)
            locManager.startMonitoring(for: region2!)
            locManager.startMonitoring(for: region3!)
            
            // TODO: Mark log entries as "saved to db" only when successfully save. That way if
            // there's a failure then we can retry all unsaved entries.
            maybeUploadLocationsToDb()
            maybeReloadRecentLogView()
        }
    }
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        LogEntry.log(msg: "location updates paused", url: LogEntry.AppLogsURL)
    }
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        LogEntry.log(msg: "location updates resumed", url: LogEntry.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LogEntry.log(msg: "error: \(error.localizedDescription)", url: LogEntry.AppLogsURL)
        regionMsg.text = "error: " + error.localizedDescription
        maybeReloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        LogEntry.log(msg: "defer error: \(error.debugDescription)", url: LogEntry.AppLogsURL)
        regionMsg.text = "error"
        maybeReloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        LogEntry.log(msg: "auth status is \(authToStr(status: status))", url: LogEntry.AppLogsURL)
        if status == CLAuthorizationStatus.authorizedAlways {
            // locManager.requestLocation()
            locManager.startUpdatingLocation()
        }
        maybeReloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        LogEntry.log(
            msg: "monitor error for region \(region?.identifier ?? "<none>"): \(error.localizedDescription)",
            url: LogEntry.AppLogsURL)
        regionMsg.text = "error"
        maybeReloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        LogEntry.log(msg: "exited region \(region.identifier)", url: LogEntry.AppLogsURL)
        maybeReloadRecentLogView()
        // locManager.requestLocation()
        locManager.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        LogEntry.log(msg: "entered region \(region.identifier)", url: LogEntry.AppLogsURL)
        maybeReloadRecentLogView()
    }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        LogEntry.log(msg: "region \(region.identifier) state is \(stateToStr(state: state))", url: LogEntry.AppLogsURL)
        maybeReloadRecentLogView()
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

