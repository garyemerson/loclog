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

    // Override point for customization after application launch.
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let start = CFAbsoluteTimeGetCurrent()
        LogUtil.log(
            msg: "app launched with options: " + (launchOptions?.map({opt in opt.key.rawValue}).joined(separator: ",") ?? "<none>"),
            url: LogUtil.AppLogsURL)
        LogUtil.log(
            msg: "deferredLocationUpdatesAvailable: \(CLLocationManager.deferredLocationUpdatesAvailable())",
            url: LogUtil.AppLogsURL)
        LogUtil.log(
            msg: "locations services enabled: \(CLLocationManager.locationServicesEnabled())",
            url: LogUtil.AppLogsURL)
        print(String(format: "%.3fs", CFAbsoluteTimeGetCurrent() - start))
        
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

            LogUtil.log(msg: "starting monitoring of visits", url: LogUtil.AppLogsURL)
            locManager.startMonitoringVisits()

            if CLLocationManager.significantLocationChangeMonitoringAvailable() {
                LogUtil.log(msg: "starting monitoring of significant location changes", url: LogUtil.AppLogsURL)
                locManager.startMonitoringSignificantLocationChanges()
            } else {
                LogUtil.log(msg: "significant locations changes API not available", url: LogUtil.AppLogsURL)
            }
        } else {
            LogUtil.log(msg: "requesting always auth", url: LogUtil.AppLogsURL)
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
            LogUtil.log(msg: "too many requests made, skipping", url: LogUtil.AppLogsURL)
        }
    }
      
    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        LogUtil.log(msg: "about to resign", url: LogUtil.AppLogsURL)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        LogUtil.log(msg: "went to background", url: LogUtil.AppLogsURL)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        LogUtil.log(msg: "went to foreground", url: LogUtil.AppLogsURL)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        LogUtil.log(msg: "activated", url: LogUtil.AppLogsURL)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        LogUtil.log(msg: "about to terminate", url: LogUtil.AppLogsURL)
    }
    
    func foobar() {
//        try! FileManager.default.copyItem(atPath: NSHomeDirectory() + "/Documents/app_logs", toPath: NSHomeDirectory() + "/Documents/app_logs.og")
        
        //        print("files:\n  " + ((FileManager.default.enumerator(atPath: NSHomeDirectory())!.allObjects as? [String])?.joined(separator: "\n  ") ?? ""))
        print("username: \(NSFullUserName())")
        print("home dir: \(NSHomeDirectory())")
        print("tmp dir: \(NSTemporaryDirectory())")
        print("files:")
        let file_infos: [(String, UInt64, String?)] = FileManager
            .default
            .enumerator(atPath: NSHomeDirectory())!
            .compactMap({ f in
                guard let dict = try? FileManager.default.attributesOfItem(atPath: NSHomeDirectory() + "/\(f)") as NSDictionary else {
                    return nil
                }
                return ("\(f)", dict.fileSize(), dict.fileType())
            })
            .sorted(by: { (a, b) in
                if a.2 == "NSFileTypeRegular" && b.2 != "NSFileTypeRegular" {
                    return true
                } else if a.2 != "NSFileTypeRegular" && b.2 == "NSFileTypeRegular" {
                    return false
                } else {
                    return a.1 > b.1
                }
            })
        for fi in file_infos.filter({ (name, size, type) in true || !name.starts(with: "Documents/") }) {
            let typeChar = fi.2 == "NSFileTypeRegular" ? "f" : fi.2 == "NSFileTypeDirectory" ? "d" : "?"
            print("  (\(fi.1), \(typeChar))\t\(fi.0)")
//            do {
//                try FileManager.default.removeItem(atPath: NSHomeDirectory() + "/\(fi.0)")
//            } catch {
//                print("failed to delete \(fi.0)")
//            }
        }
        
//                do {
//                    try FileManager.default.removeItem(at: URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("tmp/foobar"))
//                    print("remove success")
//                } catch {
//                    print("remove failed: \(error)")
//                }
//                let filePath = NSTemporaryDirectory() + "/foobar"
//                print("file path is: \(filePath)")
//                if !FileManager.default.createFile(atPath: filePath, contents: Data()) {
//                    print("file creation failed")
//                }
        
//        let startTime = CFAbsoluteTimeGetCurrent()
//        if let h = FileHandle(forUpdatingAtPath: NSHomeDirectory() + "/Documents/app_logs") {
//            for _ in 0..<1_000 {
//                h.seekToEndOfFile()
//                h.seek(toFileOffset: 0)
//            }
//            //            let data = h.readDataToEndOfFile()
//            //            print("read \(data.count) bytes")
//        } else {
//            print("open failed")
//        }
//        print(String(format: "open/seek elapsed: %.6fs", CFAbsoluteTimeGetCurrent() - startTime))
        
//        let foo =
//            false ? "bar" :
//            false ? "baz" :
//            false ? "qux" :
//            "fuck";
//        print("foo is \(foo)")
        
//        print("encoded to:", String(data: try! JSONEncoder().encode("foo\nbar\nbaz{"), encoding: .utf8)!)
//        print("encoded to:", String(data: try! JSONEncoder().encode(LogEntry(time: Date(), msg: "foo")), encoding: .utf8)!)
////        print("encode test:", (try? JSONDecoder().decode(String.self, from: JSONEncoder().encode("foo\nbar\nbaz{")) ?? "")!)
        
//        let logs = LogEntry.loadLogs(url: LogEntry.DocumentsDirectory.appendingPathComponent("app_logs.og"))
//        LogUtil.clear(url: LogUtil.AppLogsURL)
//        for l in logs {
//            print("\(l.timeLogged): \(l.msg)")
//            LogUtil.logRaw(date: l.timeLogged, msg: l.msg, url: LogUtil.AppLogsURL)
//        }
//        print("\(LogUtil.load(url: LogUtil.AppLogsURL).count) new logs")
//        print("\(logs.count) og logs")
//        print("done")
    }
}
