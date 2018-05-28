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
    var locManager: CLLocationManager = CLLocationManager()
    var locDelegate = LocationDelegate()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        LogEntry.log(
            msg: "app launched with options: " + (launchOptions == nil ? "<none>" : launchOptions!.map({$0.key.rawValue}).joined(separator: ",")),
            url: LogEntry.AppLogsURL)
        
        locManager.delegate = locDelegate
        if CLLocationManager.authorizationStatus() == CLAuthorizationStatus.authorizedAlways {
            LogEntry.log(msg: "starting monitoring of visits", url: LogEntry.AppLogsURL)
            locManager.startMonitoringVisits()

            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                LogEntry.log(msg: "starting monitoring of significant location changes", url: LogEntry.AppLogsURL)
                locManager.startMonitoringSignificantLocationChanges()
            } else {
                LogEntry.log(msg: "significant locations changes API not available", url: LogEntry.AppLogsURL)
            }
        } else {
            locManager.requestAlwaysAuthorization()
        }
        //locManager.allowDeferredLocationUpdates(untilTraveled: CLLocationDistanceMax, timeout: 2)
        locManager.allowsBackgroundLocationUpdates = true
        locManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locManager.distanceFilter = kCLLocationAccuracyHundredMeters
                
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("requestLocation"),
            object: nil,
            queue: OperationQueue.main) { (note) in
                self.locManager.requestLocation()
        }
        
        return true
    }
    
    func locationUpdateRequested(notification: Notification) {
        self.locManager.requestLocation()
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
