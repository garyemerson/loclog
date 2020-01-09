//
//  LogEntry.swift
//  loclog
//
//  Created by Garrett Mohammadioun on 1/21/18.
//  Copyright © 2018 Garrett Mohammadioun. All rights reserved.
//

import Foundation

public enum LogType {
    case Location
    case App
    case Visit
}

public struct LogEntry: Encodable, Decodable {
    var time: Date
    var msg: String
}

public class LogUtil {
    static let DocumentsDirectory: URL = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
    static let LastLocationUploadUrl: URL = DocumentsDirectory.appendingPathComponent("last_location_upload")
    static let LastVisitUploadUrl: URL = DocumentsDirectory.appendingPathComponent("last_visit_upload")
    static let LocationLogsURL: URL = DocumentsDirectory.appendingPathComponent("location_logs")
    static let VisitLogsURL: URL = DocumentsDirectory.appendingPathComponent("visit_logs")
    static let AppLogsURL: URL = DocumentsDirectory.appendingPathComponent("app_logs")
    static let jsonEncoder: JSONEncoder = JSONEncoder()
    static let jsonDecoder: JSONDecoder = JSONDecoder()
    
    static func logRaw(date: Date, msg: String, url: URL) {
        let h = try! FileHandle(forUpdating: url)
        let jsonStr = String(data: try! jsonEncoder.encode(LogEntry(time: date, msg: msg)), encoding: .utf8)!
        h.seekToEndOfFile()
        h.write("\(jsonStr)\n".data(using: .utf8)!)
    }
    
    static func log(msg: String, url: URL) {
        print(msg)
        createIfNotExist(url: url)
        let h = try! FileHandle(forUpdating: url)
        let jsonStr = String(data: try! jsonEncoder.encode(LogEntry(time: Date(), msg: msg)), encoding: .utf8)!
        h.seekToEndOfFile()
        h.write("\(jsonStr)\n".data(using: .utf8)!)
        sendNotification(url: url)
    }
    
    static func log(msgs: [String], url: URL) {
        createIfNotExist(url: url)
        let h = try! FileHandle(forUpdating: url)
        h.seekToEndOfFile()
        for m in msgs {
            print(m)
            let jsonStr = String(data: try! jsonEncoder.encode(LogEntry(time: Date(), msg: m)), encoding: .utf8)!
            h.write("\(jsonStr)\n".data(using: .utf8)!)
        }
        sendNotification(url: url)
    }
    
    static func load(url: URL, last: Int? = nil) -> [LogEntry] {
        createIfNotExist(url: url)
        var lines: [String] = try! String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: .newlines)
        if let last = last {
            lines = lines.suffix(last)
        }
        lines = lines.filter({ l in !l.isEmpty})
        return lines.map({ l in try! jsonDecoder.decode(LogEntry.self, from: l.data(using: .utf8)!)})
    }
    
    static func clear(url: URL) {
        createIfNotExist(url: url)
        try! FileHandle(forUpdating: url).truncateFile(atOffset: 0)
    }
    
    static func setMarker(date: Date, url: URL) {
        createIfNotExist(url: url)
        let h = try! FileHandle(forUpdating: url)
        try! FileHandle(forUpdating: url).truncateFile(atOffset: 0)
        h.write(try! jsonEncoder.encode(date))
    }
    
    static func getMarker(url: URL) -> Date? {
        createIfNotExist(url: url)
        return try? jsonDecoder.decode(Date.self, from: Data(contentsOf: url))
    }
    
    static func sendNotification(url: URL) {
        var maybeNoti: String? = nil
        if url == LogUtil.AppLogsURL {
            maybeNoti = "appLogUpdated"
        } else if url == LogUtil.LocationLogsURL {
            maybeNoti = "locationLogUpdated"
        }
        
        if let noti = maybeNoti {
            NotificationCenter.default.post(name: NSNotification.Name(noti), object: nil)
        }
    }
    
    private static func createIfNotExist(url: URL) {
        if !FileManager.default.fileExists(atPath: url.path) {
            FileManager.default.createFile(atPath: url.path, contents: nil)
        }
    }
}

//public struct PropertyKey {
//    static let datetime = "datetime"
//    static let msg = "msg"
//}
//class LogEntry: NSObject, NSCoding {
//    var timeLogged: Date
//    var msg: String
//
//    static let DocumentsDirectory = FileManager().urls(for: .documentDirectory, in: .userDomainMask).first!
//    static let LastLocationUploadUrl = DocumentsDirectory.appendingPathComponent("last_location_upload")
//    static let LastVisitUploadUrl = DocumentsDirectory.appendingPathComponent("last_visit_upload")
//    static let LocationLogsURL = DocumentsDirectory.appendingPathComponent("location_logs")
//    static let VisitLogsURL = DocumentsDirectory.appendingPathComponent("visit_logs")
//    static let AppLogsURL = DocumentsDirectory.appendingPathComponent("app_logs")
//
//    static func saveLogs(logs: [LogEntry], url: URL) {
//        if !NSKeyedArchiver.archiveRootObject(logs, toFile: url.path) {
//            print("Failed to save logs")
//        }
//        sendNotification(url: url)
//    }
//
//    static func loadLogs(url: URL) -> [LogEntry] {
//        // return NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? [LogEntry2]
//        if let logs = NSKeyedUnarchiver.unarchiveObject(withFile: url.path) as? [LogEntry] {
//            return logs
//        } else {
//            return [LogEntry]()
//        }
//    }
//
//    static func log(msgs: [String], url: URL) {
//        for m in msgs {
//            print(m)
//        }
//
//        var logs = loadLogs(url: url)
//        logs.append(contentsOf: msgs.map({LogEntry(timeLogged: Date(), msg: $0)}))
//        saveLogs(logs: logs, url: url)
//        sendNotification(url: url)
//    }
//
//    static func log(msg: String, url: URL) {
//        print(msg)
//        var logs = loadLogs(url: url)
//        logs.append(LogEntry(timeLogged: Date(), msg: msg))
//        saveLogs(logs: logs, url: url)
//        sendNotification(url: url)
//    }
//
//    static func sendNotification(url: URL) {
//        var maybeNoti: String? = nil
//        if url == LogEntry.AppLogsURL {
//            maybeNoti = "appLogUpdated"
//        } else if url == LogEntry.LocationLogsURL {
//            maybeNoti = "locationLogUpdated"
//        }
//        if let noti = maybeNoti {
//            NotificationCenter.default.post(name: NSNotification.Name(noti), object: nil)
//        }
//    }
//
//    func encode(with aCoder: NSCoder) {
//        aCoder.encode(timeLogged, forKey: PropertyKey.datetime)
//        aCoder.encode(msg, forKey: PropertyKey.msg)
//    }
//
//    required init(timeLogged: Date, msg: String) {
//        self.timeLogged = timeLogged
//        self.msg = msg
//    }
//
//    required convenience init?(coder aDecoder: NSCoder) {
//        // The name is required. If we cannot decode a name string, the initializer should fail.
//        guard let datetime = aDecoder.decodeObject(forKey: PropertyKey.datetime) as? Date else {
//            print("Unable to decode the timeLogged for a LogEntry2 object.")
//            return nil
//        }
//        guard let msg = aDecoder.decodeObject(forKey: PropertyKey.msg) as? String else {
//            print("Unable to decode the msg for a LogEntry2 object.")
//            return nil
//        }
//
//        self.init(timeLogged: datetime, msg: msg)
//    }
//}
