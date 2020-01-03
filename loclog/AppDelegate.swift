//
//  AppDelegate.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 1/15/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import UIKit
import CoreLocation

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var locManager = CLLocationManager()
    var locDelegate = LocationDelegate()
    var requests: [Date] = []

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        LogEntry.log(
            msg: "app launched with options: " + (launchOptions?.map({opt in opt.key.rawValue}).joined(separator: ",") ?? "<none>"),
            url: LogEntry.AppLogsURL)
        LogEntry.log(
            msg: "deferredLocationUpdatesAvailable: \(CLLocationManager.deferredLocationUpdatesAvailable())",
            url: LogEntry.AppLogsURL)
        LogEntry.log(
            msg: "locations services enabled: \(CLLocationManager.locationServicesEnabled())",
            url: LogEntry.AppLogsURL)
        
        setupLocationMonitoring()
//        foobar()
        
        return true
    }
    
    func setupLocationMonitoring() {
        locManager.delegate = locDelegate
        locManager.allowsBackgroundLocationUpdates = true
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        locManager.distanceFilter = kCLDistanceFilterNone
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways {
            // LogEntry.log(msg: "making one-off request", url: LogEntry.AppLogsURL)
            // locManager.requestLocation()

            LogEntry.log(msg: "starting monitoring of visits", url: LogEntry.AppLogsURL)
            locManager.startMonitoringVisits()

            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                LogEntry.log(msg: "starting monitoring of significant location changes", url: LogEntry.AppLogsURL)
                locManager.startMonitoringSignificantLocationChanges()
            } else {
                LogEntry.log(msg: "significant locations changes API not available", url: LogEntry.AppLogsURL)
            }
        } else {
            LogEntry.log(msg: "requesting always auth", url: LogEntry.AppLogsURL)
            locManager.requestAlwaysAuthorization()
        }

        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("requestLocation"),
            object: nil,
            queue: OperationQueue.main) { (note) in self.requestLocationWithRateLimiting() }
    }

    func requestLocationWithRateLimiting() {
        if self.requests.filter({d in d.timeIntervalSinceNow <= (60 * 60)}).count < 30 &&
            self.requests.filter({d in d.timeIntervalSinceNow <= (10 * 60)}).count < 20 &&
            self.requests.filter({d in d.timeIntervalSinceNow <= 60}).count < 10
        {
            print("requesting location")
            self.locManager.requestLocation()
            self.requests.append(Date())
            self.requests = self.requests.filter({d in d.timeIntervalSinceNow > (60 * 60)})
        } else {
            LogEntry.log(msg: "too many requests made, skipping", url: LogEntry.AppLogsURL)
        }
    }
    
    func foobar() {
        //        print("files:\n  " + ((FileManager.default.enumerator(atPath: NSHomeDirectory())!.allObjects as? [String])?.joined(separator: "\n  ") ?? ""))
        print("username: \(NSFullUserName())")
        print("home dir: \(NSHomeDirectory())")
        print("tmp dir: \(NSTemporaryDirectory())")
        print("files (sizes)")
        for f in FileManager.default.enumerator(atPath: NSHomeDirectory())! {
            if let dict = try? FileManager.default.attributesOfItem(atPath: NSHomeDirectory() + "/\(f)") {
                let size = (dict as NSDictionary).fileSize()
                print("  \(f) (\(size))")
            } else {
                print("  <error>")
            }
        }
        
        //        do {
        //            try FileManager.default.removeItem(at: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("tmp/foobar"))
        //            print("remove success")
        //        } catch {
        //            print("remove failed: \(error)")
        //        }
        //        let filePath = NSTemporaryDirectory() + "/foobar"
        //        print("file path is: \(filePath)")
        //        if !FileManager.default.createFile(atPath: filePath, contents: Data()) {
        //            print("file creation failed")
        //        }
        
        let startTime = CFAbsoluteTimeGetCurrent()
        if let h = FileHandle(forUpdatingAtPath: NSHomeDirectory() + "/Documents/app_logs") {
            for _ in 0..<1_000 {
                h.seekToEndOfFile()
                h.seek(toFileOffset: 0)
            }
            //            let data = h.readDataToEndOfFile()
            //            print("read \(data.count) bytes")
        } else {
            print("open failed")
        }
        print("open/seek elapsed: \(CFAbsoluteTimeGetCurrent() - startTime)s")
    }
    
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        LogEntry.log(msg: "about to resign", url: LogEntry.AppLogsURL)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        LogEntry.log(msg: "went to background", url: LogEntry.AppLogsURL)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        LogEntry.log(msg: "went to foreground", url: LogEntry.AppLogsURL)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        LogEntry.log(msg: "activated", url: LogEntry.AppLogsURL)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        LogEntry.log(msg: "about to terminate", url: LogEntry.AppLogsURL)
    }
}
