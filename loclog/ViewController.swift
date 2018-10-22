//
//  ViewController.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 1/15/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import UIKit
import CoreLocation

class ViewController: UIViewController, UITextViewDelegate {
    //MARK: Properties
    @IBOutlet weak var regionMsg: UITextView!
    @IBOutlet weak var recentLogs: UITextView!
    @IBOutlet weak var currentLogLabel: UILabel!
    
    var locManager = CLLocationManager()
    var currLog = LogType.App
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        regionMsg.delegate = self
        regionMsg.text = getRegionStr(regions: Array(locManager.monitoredRegions))
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("appLogUpdated"),
            object: nil,
            queue: OperationQueue.main,
            using: logsChanged(notification:))
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("locationLogUpdated"),
            object: nil,
            queue: OperationQueue.main,
            using: logsChanged(notification:))
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("regionsUpdated"),
            object: nil,
            queue: OperationQueue.main,
            using: regionsChanged(notification: ))

        maybeReloadRecentLogView()
    }
    
    func logsChanged(notification: Notification) {
        self.maybeReloadRecentLogView()
    }
    
    func regionsChanged(notification: Notification) {
        regionMsg.text = getRegionStr(regions: notification.object! as! [CLRegion])
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
        LogEntry.saveLogs(logs: [], url: LogEntry.AppLogsURL)
        LogEntry.saveLogs(logs: [], url: LogEntry.LocationLogsURL)
        maybeReloadRecentLogView()
    }
    
    @IBAction func refresh(_ sender: UIButton) {
        regionMsg.text = getRegionStr(regions: Array(locManager.monitoredRegions))
//        NotificationCenter.default.post(Notification(name: Notification.Name("requestLocation")))
        LocationDelegate().maybeUpload(dataType: "visits")
        LocationDelegate().maybeUpload(dataType: "locations")
        maybeReloadRecentLogView()
    }
    
    func getRegionStr(regions: [CLRegion]) -> String {
        return regions.map({
            var s = "region \($0.identifier)\n"
            if $0 is CLCircularRegion {
                let r = $0 as! CLCircularRegion
                s += String(format: "center: %f, %f\n", r.center.latitude, r.center.longitude)
                s += String(format: "radius: %f\n", r.radius)
            }
            return s
        })
        .joined(separator: "\n")
    }
    
    @IBAction func switchLogs(_ sender: UIButton) {
        if currLog == LogType.App {
            currLog = LogType.Location
            maybeReloadRecentLogView()
            sender.setTitle("View Visit Logs", for: UIControlState.normal)
            sender.sizeToFit()
//            sender.frame.origin.x = sender.frame.origin.x + 31
            currentLogLabel.text = "Location Logs"
        } else if currLog == LogType.Location {
            currLog = LogType.Visit
            maybeReloadRecentLogView()
            sender.setTitle("View App Logs", for: UIControlState.normal)
            sender.sizeToFit()
//            sender.frame.origin.x = sender.frame.origin.x + 31
            currentLogLabel.text = "Visit Logs"
        } else {
            currLog = LogType.App
            maybeReloadRecentLogView()
            sender.contentMode = UIViewContentMode.right
            sender.setTitle("View Location Logs", for: UIControlState.normal)
            sender.sizeToFit()
//            sender.frame.origin.x = sender.frame.origin.x - 31
            currentLogLabel.text = "App Logs"
        }
    }

    func maybeReloadRecentLogView() {
        if UIApplication.shared.applicationState != UIApplicationState.background {
            let maybeLogs: [LogEntry]?
            if currLog == LogType.App {
                maybeLogs = LogEntry.loadLogs(url: LogEntry.AppLogsURL)
            } else if currLog == LogType.Location {
                maybeLogs = LogEntry.loadLogs(url: LogEntry.LocationLogsURL)
            } else {
                maybeLogs = LogEntry.loadLogs(url: LogEntry.VisitLogsURL)
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
}

