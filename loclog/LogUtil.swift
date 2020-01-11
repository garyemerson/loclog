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
