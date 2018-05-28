//
//  LogEntry.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 1/21/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import Foundation

public struct PropertyKey {
    static let datetime = "datetime"
    static let msg = "msg"
}

public enum LogType {
    case Location
    case App
}

class LogEntry: NSObject, NSCoding {
    var timeLogged: Date
    var msg: String
    
    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let LastUploadUrl = DocumentsDirectory.appendingPathComponent("last_upload")
    static let LocationLogsURL = DocumentsDirectory.appendingPathComponent("location_logs")
    static let AppLogsURL = DocumentsDirectory.appendingPathComponent("app_logs")
    
    static func saveLogs(logs: [LogEntry], url: URL) {
        if !NSKeyedArchiver.archiveRootObject(logs, toFile: url.path) {
            print("Failed to save logs")
        }
        sendNotification(url: url)
    }
    
    static func loadLogs(url: URL) -> [LogEntry] {
//        return NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? [LogEntry]
        if let logs = NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? [LogEntry] {
            return logs
        } else {
            return [LogEntry]()
        }
    }
    
    static func log(msgs: [String], url: URL) {
        for m in msgs {
            print(m)
        }

        var logs = loadLogs(url: url)
        logs.append(contentsOf: msgs.map({LogEntry(timeLogged: Date(), msg: $0)}))
        saveLogs(logs: logs, url: url)
        sendNotification(url: url)
    }
    
    static func log(msg: String, url: URL) {
        print(msg)
        var logs = loadLogs(url: url)
        logs.append(LogEntry(timeLogged: Date(), msg: msg))
        saveLogs(logs: logs, url: url)
        sendNotification(url: url)
    }
    
    static func sendNotification(url: URL) {
        var maybeNoti: String? = nil
        if url == LogEntry.AppLogsURL {
            maybeNoti = "appLogUpdated"
        } else if url == LogEntry.LocationLogsURL {
            maybeNoti = "locationLogUpdated"
        }
        if let noti = maybeNoti {
            NotificationCenter.default.post(name: NSNotification.Name(noti), object: nil)
        }
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(timeLogged, forKey: PropertyKey.datetime)
        aCoder.encode(msg, forKey: PropertyKey.msg)
    }
    
    required init(timeLogged: Date, msg: String) {
        self.timeLogged = timeLogged
        self.msg = msg
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let datetime = aDecoder.decodeObject(forKey: PropertyKey.datetime) as? Date else {
            print("Unable to decode the timeLogged for a LogEntry object.")
            return nil
        }
        guard let msg = aDecoder.decodeObject(forKey: PropertyKey.msg) as? String else {
            print("Unable to decode the msg for a LogEntry object.")
            return nil
        }
        
        self.init(timeLogged: datetime, msg: msg)
    }
}


class LogEntry2<T>: NSObject, NSCoding {
    var timeLogged: Date
    var data: T
    
    static func saveLogs(logs: [LogEntry], url: URL) {
        if !NSKeyedArchiver.archiveRootObject(logs, toFile: url.path) {
            print("Failed to save logs")
        }
    }
    
    static func loadLogs(url: URL) -> [LogEntry]? {
        //        return NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? [LogEntry]
        if let logs = NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? [LogEntry] {
            return logs
        } else {
            return [LogEntry]()
        }
    }
    
    static func appendLog(msg: String, url: URL) {
        if var logs = loadLogs(url: url) {
            logs.append(LogEntry(timeLogged: Date(), msg: msg))
            saveLogs(logs: logs, url: url)
        }
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(timeLogged, forKey: PropertyKey.datetime)
        aCoder.encode(data, forKey: PropertyKey.msg)
    }
    
    required init(timeLogged: Date, data: T) {
        self.timeLogged = timeLogged
        self.data = data
    }
    
    required convenience init?(coder aDecoder: NSCoder) {
        // The name is required. If we cannot decode a name string, the initializer should fail.
        guard let datetime = aDecoder.decodeObject(forKey: PropertyKey.datetime) as? Date else {
            print("Unable to decode the timeLogged for a LogEntry object.")
            return nil
        }
        guard let data = aDecoder.decodeObject(forKey: PropertyKey.msg) as? T else {
            print("Unable to decode the msg for a LogEntry object.")
            return nil
        }
        
        self.init(timeLogged: datetime, data: data)
    }
}

