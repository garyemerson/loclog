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
    @IBOutlet weak var logButton: UIButton!
    @IBOutlet weak var recentLogs: UITextView!
    @IBOutlet weak var doubleTapGesture: UITapGestureRecognizer!
//    @IBOutlet weak var currentLogLabel: UILabel!
    var currLog = LogType.App
    

    override func viewDidLoad() {
        print("view did load")
        super.viewDidLoad()
        doubleTapGesture.numberOfTapsRequired = 2;
//        self.recentLogs.attributedText = NSAttributedString(string: "loading logs...")
        
//        let startTime = CFAbsoluteTimeGetCurrent()
//        let s = NSMutableAttributedString()
//        for _ in 0..<10_000 {
//            let temp = NSMutableAttributedString(string: "foo", attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
//            temp.append(NSAttributedString(string: "barbaz\n"))
//            s.append(temp)
//        }
//        self.recentLogs.attributedText = s
//        print("log elapsed: \(CFAbsoluteTimeGetCurrent() - startTime)s")
        
        // Do any additional setup after loading the view, typically from a nib.
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
        reloadLogView()
    }
    
    func logsChanged(notification: Notification) {
        print("logs changed")
        self.reloadLogView()
    }
    
    override func viewDidAppear(_ animated: Bool) {
//        print("view did appear")
//        maybeReloadRecentLogView()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    //MARK: Actions
    @IBAction func action(_ sender: UIButton) {
        let alert = UIAlertController(title: "Action", message: "", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Request Location", style: .default, handler: { _ in
            NotificationCenter.default.post(Notification(name: Notification.Name("requestLocation")))
        }))
        alert.addAction(UIAlertAction(title: "Upload Location Data", style: .default, handler: { _ in
            LocationDelegate().upload(dataType: "visits")
            LocationDelegate().upload(dataType: "locations")
            self.reloadLogView()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true)
    }
    
    @IBAction func logsDoubleTap(_ sender: UITapGestureRecognizer) {
        self.switchLogs()
    }
    
    @IBAction func logButtonPressed(_ sender: UIButton) {
        self.switchLogs()
    }
    
    func switchLogs() {
        print("in switchLogs")
        let nextLog = [LogType.App: LogType.Location, LogType.Location: LogType.Visit, LogType.Visit: LogType.App]
        self.currLog = nextLog[self.currLog] ?? LogType.App
        self.logButton.setTitle("\(self.currLog) Logs", for: .normal)
        self.reloadLogView()
    }

    func reloadLogView() {
        let logTypeToUrl = [LogType.App: LogEntry.AppLogsURL, LogType.Location: LogEntry.LocationLogsURL, LogType.Visit: LogEntry.VisitLogsURL]
        let logType = self.currLog
        let logs: [LogEntry] = LogEntry.loadLogs(url: logTypeToUrl[logType] ?? LogEntry.AppLogsURL)

        var str: NSMutableAttributedString = NSMutableAttributedString()
        DispatchQueue.global(qos: .background).async {
            let dateFmt = DateFormatter()
            dateFmt.locale = Locale(identifier: "en_US")
            dateFmt.setLocalizedDateFormatFromTemplate("yyyy-MM-dd")

            let dateFmt2 = DateFormatter()
            dateFmt2.locale = Locale(identifier: "en_US")
            dateFmt2.setLocalizedDateFormatFromTemplate("HH:mm:ss")

            let recent: ArraySlice = logs.dropFirst(max(0, logs.count - 500))
            str = Dictionary(grouping: recent, by: { (e: LogEntry) in Calendar.current.startOfDay(for: e.timeLogged) })
                .sorted(by: { $0.key > $1.key })
                .map({(e) -> NSMutableAttributedString in
                    let dayLogs = NSMutableAttributedString(
                        string: "--\(dateFmt.string(from: e.key))--\n",
                        attributes: [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.backgroundColor: UIColor.blue])

                    let logLines: NSMutableAttributedString = e.value
                        .sorted(by: { (a: LogEntry, b: LogEntry) in a.timeLogged > b.timeLogged })
                        .map({(log: LogEntry) -> NSMutableAttributedString in
                            let s = NSMutableAttributedString(
                                string: "[\(dateFmt2.string(from: log.timeLogged))] ",
                                attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
                            s.append(NSAttributedString(string: log.msg + "\n"))
                            return s
                        })
                        .reduce(
                            NSMutableAttributedString(),
                            { (acc, curr) in let x = (acc.mutableCopy() as! NSMutableAttributedString); x.append(curr); return x })

                    dayLogs.append(logLines)
                    return dayLogs
                })
                .reduce(
                    NSMutableAttributedString(),
                    { (acc, curr) in let x = (acc.mutableCopy() as! NSMutableAttributedString); x.append(curr); return x })

            DispatchQueue.main.async {
                if self.currLog == logType {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    self.recentLogs.attributedText = str
                    print("done assigning recentLogs.attributedText, elapsed: \(CFAbsoluteTimeGetCurrent() - startTime)s")
                }
            }
        }
    }
}
