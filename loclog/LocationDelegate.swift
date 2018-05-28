//
//  LocationDelegate.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 5/27/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import Foundation
import CoreLocation


class LocationDelegate: NSObject, CLLocationManagerDelegate {
    func maybeUploadLocationsToDb() {
        let lastUpdate = LogEntry.loadLogs(url: LogEntry.LastLocationUploadUrl).max(by: { $0.timeLogged < $1.timeLogged })
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
                        locations.map({$0.msg}).joined(separator: ",\n");
                    
                    let result = String(cString: exec_query(query))
                    DispatchQueue.main.async {
                        if result == "" {
                            LogEntry.log(msg: "db save succeeded", url: LogEntry.AppLogsURL)
                            LogEntry.saveLogs(logs: [], url: LogEntry.LocationLogsURL)
                            LogEntry.saveLogs(logs: [LogEntry(timeLogged: Date(), msg: "")], url: LogEntry.LastLocationUploadUrl)
                        } else {
                            LogEntry.log(msg: "db location upload failed: \(result)", url: LogEntry.AppLogsURL)
                        }
                    }
                }
            }
        } else {
            LogEntry.log(msg: "Recent location upload \(Int(lastUpdate!.timeLogged.timeIntervalSinceNow)) seconds ago, skipping", url: LogEntry.AppLogsURL)
        }
    }
    
    func maybeUploadVisitsToDb() {
        let lastUpdate = LogEntry.loadLogs(url: LogEntry.LastVisitUploadUrl).max(by: { $0.timeLogged < $1.timeLogged })
        if lastUpdate == nil || lastUpdate!.timeLogged.timeIntervalSinceNow < -(10 * 60) {
            let visits = LogEntry.loadLogs(url: LogEntry.VisitLogsURL)
            LogEntry.log(msg: "attempting upload of \(visits.count) visits(s) to db", url: LogEntry.AppLogsURL)
            if (!visits.isEmpty) {
                // regionMsg.text = "running query..."
                
                // TODO: perhaps batch dbs calls to something like 1000 locations a batch so a single query
                // doesn't take very long. This minimize the harm done if a query gets cut off bc then hopefully
                // at least some queries before it could finish.
                DispatchQueue.global(qos: .background).async {
                    let query =
                        "insert into visits (arrival,departure,latitude,longitude,horizontal_accuracy)\n" +
                        "values\n" +
                        visits.map({$0.msg}).joined(separator: ",\n");
                    
                    let result = String(cString: exec_query(query))
                    DispatchQueue.main.async {
                        if result == "" {
                            LogEntry.log(msg: "db save succeeded", url: LogEntry.AppLogsURL)
                            LogEntry.saveLogs(logs: [], url: LogEntry.VisitLogsURL)
                            LogEntry.saveLogs(logs: [LogEntry(timeLogged: Date(), msg: "")], url: LogEntry.LastVisitUploadUrl)
                        } else {
                            LogEntry.log(msg: "db visit upload failed: \(result)", url: LogEntry.AppLogsURL)
                        }
                    }
                }
            }
        } else {
            LogEntry.log(msg: "Recent visit upload \(Int(lastUpdate!.timeLogged.timeIntervalSinceNow)) seconds ago, skipping", url: LogEntry.AppLogsURL)
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
    
    func visitToStr(visit: CLVisit) -> String {
        return
            """
            ('\(visit.arrivalDate)', '\(visit.departureDate)', \(visit.coordinate.latitude),
            \(visit.coordinate.longitude), \(visit.horizontalAccuracy)
            """
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty {
            LogEntry.log(msg: "received location update", url: LogEntry.AppLogsURL)
            LogEntry.log(
                msgs: locations.map(locationToStr),
                url: LogEntry.LocationLogsURL)
            
            // let coord = locations.max(by: { $0.timestamp < $1.timestamp })!.coordinate
            // LogEntry.log(msg: "creating new regions with center \(coord)", url: LogEntry.AppLogsURL)
            // let region = CLCircularRegion(center: coord, radius: 10, identifier: "foobar")
            // let region2 = CLCircularRegion(center: coord, radius: 100, identifier: "foobar2")
            // let region3 = CLCircularRegion(center: coord, radius: 1000, identifier: "foobar3")
            // let region4 = CLCircularRegion(center: coord, radius: 10000, identifier: "foobar4")
            // NotificationCenter.default.post(name: NSNotification.Name("regionsUpdated"), object: [ region, region2, region3, region4 ])
            // manager.startMonitoring(for: region)
            // manager.startMonitoring(for: region2)
            // manager.startMonitoring(for: region3)
            // manager.startMonitoring(for: region4)
            
            // TODO: Mark log entries as "saved to db" only when successfully save. That way if
            // there's a failure then we can retry all unsaved entries.
            maybeUploadLocationsToDb()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        LogEntry.log(msg: "received visit update", url: LogEntry.AppLogsURL)
        LogEntry.log(msg: visitToStr(visit: visit), url: LogEntry.VisitLogsURL)
        maybeUploadVisitsToDb()
    }
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        LogEntry.log(msg: "location updates paused", url: LogEntry.AppLogsURL)
    }
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        LogEntry.log(msg: "location updates resumed", url: LogEntry.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LogEntry.log(msg: "error: \(error.localizedDescription)", url: LogEntry.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        LogEntry.log(msg: "defer error: \(error.debugDescription)", url: LogEntry.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        LogEntry.log(msg: "auth status is \(authToStr(status: status))", url: LogEntry.AppLogsURL)
        if status == CLAuthorizationStatus.authorizedAlways {
            LogEntry.log(msg: "starting monitoring of visits", url: LogEntry.AppLogsURL)
            manager.startMonitoringVisits()
            
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                LogEntry.log(msg: "starting monitoring of significant location changes", url: LogEntry.AppLogsURL)
                manager.startMonitoringSignificantLocationChanges()
            } else {
                LogEntry.log(msg: "significant locations changes API not available", url: LogEntry.AppLogsURL)
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        LogEntry.log(
            msg: "monitor error for region \(region?.identifier ?? "<none>"): \(error.localizedDescription)",
            url: LogEntry.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        LogEntry.log(msg: "exited region \(region.identifier)", url: LogEntry.AppLogsURL)
        // locManager.requestLocation()
        manager.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        LogEntry.log(msg: "entered region \(region.identifier)", url: LogEntry.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        LogEntry.log(msg: "region \(region.identifier) state is \(stateToStr(state: state))", url: LogEntry.AppLogsURL)
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
