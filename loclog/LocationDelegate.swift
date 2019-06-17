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
    func maybeUpload(dataType: String) {
        let lastUploadUrl = dataType == "visits" ? LogEntry.LastVisitUploadUrl : LogEntry.LastLocationUploadUrl

        let lastUpdate = LogEntry.loadLogs(url: lastUploadUrl).max(by: { $0.timeLogged < $1.timeLogged })
        if lastUpdate == nil || lastUpdate!.timeLogged.timeIntervalSinceNow < -(10 * 60) {
            upload(dataType: dataType)
        } else {
            LogEntry.log(
                msg: "Recent \(dataType) upload \(Int(lastUpdate!.timeLogged.timeIntervalSinceNow)) seconds ago, skipping",
                url: LogEntry.AppLogsURL)
        }
    }
    
    func upload(dataType: String) {
        let logUrl = dataType == "visits" ? LogEntry.VisitLogsURL : LogEntry.LocationLogsURL
        let lastUploadUrl = dataType == "visits" ? LogEntry.LastVisitUploadUrl : LogEntry.LastLocationUploadUrl

        let logs = LogEntry.loadLogs(url: logUrl)
        if (!logs.isEmpty) {
            LogEntry.log(msg: "attempting upload of \(logs.count) \(dataType) to db", url: LogEntry.AppLogsURL)
            
            let url = "http://unkdir.com/metrics/api/upload_" + dataType;
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let s = "[" + logs.map({l in l.msg}).joined(separator: ",") + "]"
            let data = s.data(using: .utf8)
            let task = URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
                if let error = error {
                    LogEntry.log(msg: "\(dataType) upload failed: \(error)", url: LogEntry.AppLogsURL)
                    return
                }
                guard let r = response as? HTTPURLResponse else {
                    LogEntry.log(
                        msg: "failed to cast to HTTPURLResponse attempting to upload \(dataType) data",
                        url: LogEntry.AppLogsURL)
                    return
                }
                if r.statusCode != 200 {
                    let body = String(data: data ?? Data(), encoding: .utf8) ?? String()
                    LogEntry.log(msg: "\(dataType) upload failed with \(r.statusCode): \(body)", url: LogEntry.AppLogsURL)
                    return
                }
                LogEntry.log(msg: "\(dataType) upload succeeded", url: LogEntry.AppLogsURL)
                LogEntry.saveLogs(logs: [], url: logUrl)
                LogEntry.saveLogs(logs: [LogEntry(timeLogged: Date(), msg: "")], url: lastUploadUrl)
            }
            task.resume()
        }
    }

    func locationToJson(location: CLLocation) -> String {
        return """
            {"date": "\(ISO8601DateFormatter().string(from: location.timestamp))",
            "latitude": \(location.coordinate.latitude),
            "longitude": \(location.coordinate.longitude),
            "altitude": \(location.altitude),
            "horizontal_accuracy": \(location.horizontalAccuracy),
            "vertical_accuracy": \(location.verticalAccuracy),
            "course": \(location.course),
            "speed": \(location.speed),
            "floor": \(location.floor?.description ?? "null")}
            """
    }
    
    func visitToJson(visit: CLVisit) -> String {
        let arrival = visit.arrivalDate == NSDate.distantPast ?
            "null" :
            "\"\(ISO8601DateFormatter().string(from: visit.arrivalDate))\""
        let departure = visit.departureDate == NSDate.distantFuture ?
            "null" :
            "\"\(ISO8601DateFormatter().string(from: visit.departureDate))\""

        return """
            {"arrival": \(arrival),
            "departure": \(departure),
            "latitude": \(visit.coordinate.latitude),
            "longitude": \(visit.coordinate.longitude),
            "horizontal_accuracy": \(visit.horizontalAccuracy)}
            """
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if !locations.isEmpty {
            LogEntry.log(msg: "received location update", url: LogEntry.AppLogsURL)
            LogEntry.log(
                msgs: locations.map(locationToJson),
                url: LogEntry.LocationLogsURL)
            
           // let min: Double? = locations.map({l in l.horizontalAccuracy}).min()
           // if min.map({m in m > 50}) ?? false {
           //     LogEntry.log(msg: "inaccurate location update, best is \(min!)m, requesting again", url: LogEntry.AppLogsURL)
           //     NotificationCenter.default.post(Notification(name: Notification.Name("requestLocation")))
           // }

            maybeUpload(dataType: "locations")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        LogEntry.log(msg: "received visit update", url: LogEntry.AppLogsURL)
        LogEntry.log(msg: visitToJson(visit: visit), url: LogEntry.VisitLogsURL)
        maybeUpload(dataType: "visits")
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
        manager.requestLocation()
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
