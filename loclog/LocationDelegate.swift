//
//  LocationDelegate.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 5/27/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import Foundation
import CoreLocation
import Network

class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var pathMonitor = NWPathMonitor()
    
    override init() {
        pathMonitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    func maybeUpload(dataType: String) {
        if pathMonitor.currentPath.status != .satisfied {
            LogUtil.log(msg: "internet not available, skipping upload", url: LogUtil.AppLogsURL)
            return
        }
        
        let lastUploadUrl = dataType == "visits" ? LogUtil.LastVisitUploadUrl : LogUtil.LastLocationUploadUrl
        let lastUpdate = LogUtil.getMarker(url: lastUploadUrl)
        if lastUpdate == nil || lastUpdate!.timeIntervalSinceNow < -(10 * 60) {
            LocationDelegate.upload(dataType: dataType)
        } else {
            LogUtil.log(
                msg: "Recent \(dataType) upload \(Int(lastUpdate!.timeIntervalSinceNow)) seconds ago, skipping",
                url: LogUtil.AppLogsURL)
        }
    }
    
    static func upload(dataType: String) {
        let logUrl = dataType == "visits" ? LogUtil.VisitLogsURL : LogUtil.LocationLogsURL
        let lastUploadUrl = dataType == "visits" ? LogUtil.LastVisitUploadUrl : LogUtil.LastLocationUploadUrl

        let logs = LogUtil.load(url: logUrl)
        if (!logs.isEmpty) {
            LogUtil.log(msg: "attempting upload of \(logs.count) \(dataType) to db", url: LogUtil.AppLogsURL)
            
            let url = "http://unkdir.com/metrics/api/upload_" + dataType;
            var request = URLRequest(url: URL(string: url)!)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let s = "[" + logs.map({l in l.msg}).joined(separator: ",") + "]"
            let data = s.data(using: .utf8)
            let task = URLSession.shared.uploadTask(with: request, from: data) { data, response, error in
                if let error = error {
                    LogUtil.log(msg: "\(dataType) upload failed: \(error)", url: LogUtil.AppLogsURL)
                    return
                }
                guard let r = response as? HTTPURLResponse else {
                    LogUtil.log(
                        msg: "failed to cast to HTTPURLResponse attempting to upload \(dataType) data",
                        url: LogUtil.AppLogsURL)
                    return
                }
                if r.statusCode != 200 {
                    let body = String(data: data ?? Data(), encoding: .utf8) ?? String()
                    LogUtil.log(msg: "\(dataType) upload failed with \(r.statusCode): \(body)", url: LogUtil.AppLogsURL)
                    return
                }
                LogUtil.log(msg: "\(dataType) upload succeeded", url: LogUtil.AppLogsURL)
                LogUtil.clear(url: logUrl)
                LogUtil.setMarker(date: Date(), url: lastUploadUrl)
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
            "floor": \(location.floor?.level.description ?? "null")}
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
            LogUtil.log(msg: "received location update", url: LogUtil.AppLogsURL)
            LogUtil.log(
                msgs: locations.map(locationToJson),
                url: LogUtil.LocationLogsURL)
            
           // let min: Double? = locations.map({l in l.horizontalAccuracy}).min()
           // if min.map({m in m > 50}) ?? false {
           //     LogUtil.log(msg: "inaccurate location update, best is \(min!)m, requesting again", url: LogUtil.AppLogsURL)
           //     NotificationCenter.default.post(Notification(name: Notification.Name("requestLocation")))
           // }

            maybeUpload(dataType: "locations")
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
        LogUtil.log(msg: "received visit update", url: LogUtil.AppLogsURL)
        LogUtil.log(msg: visitToJson(visit: visit), url: LogUtil.VisitLogsURL)
        maybeUpload(dataType: "visits")
    }
    func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        LogUtil.log(msg: "location updates paused", url: LogUtil.AppLogsURL)
    }
    func locationManagerDidResumeLocationUpdates(_ manager: CLLocationManager) {
        LogUtil.log(msg: "location updates resumed", url: LogUtil.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        LogUtil.log(msg: "error: \(error.localizedDescription)", url: LogUtil.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didFinishDeferredUpdatesWithError error: Error?) {
        LogUtil.log(msg: "defer error: \(error.debugDescription)", url: LogUtil.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        LogUtil.log(msg: "auth status is \(authToStr(status: status))", url: LogUtil.AppLogsURL)
        if status == CLAuthorizationStatus.authorizedAlways {
            LogUtil.log(msg: "starting monitoring of visits", url: LogUtil.AppLogsURL)
            manager.startMonitoringVisits()
            
            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                LogUtil.log(msg: "starting monitoring of significant location changes", url: LogUtil.AppLogsURL)
                manager.startMonitoringSignificantLocationChanges()
            } else {
                LogUtil.log(msg: "significant locations changes API not available", url: LogUtil.AppLogsURL)
            }
        }
    }
    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        LogUtil.log(
            msg: "monitor error for region \(region?.identifier ?? "<none>"): \(error.localizedDescription)",
            url: LogUtil.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        LogUtil.log(msg: "exited region \(region.identifier)", url: LogUtil.AppLogsURL)
        manager.requestLocation()
        manager.startUpdatingLocation()
    }
    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        LogUtil.log(msg: "entered region \(region.identifier)", url: LogUtil.AppLogsURL)
    }
    func locationManager(_ manager: CLLocationManager, didDetermineState state: CLRegionState, for region: CLRegion) {
        LogUtil.log(msg: "region \(region.identifier) state is \(stateToStr(state: state))", url: LogUtil.AppLogsURL)
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
        @unknown default:
            print("unknown CLAuthorizationStatus \(status)")
            exit(0)
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
