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
    }
    
    func logsChanged(notification: Notification) {
        print("logs changed")
        self.reloadLogView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadLogView()
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
            LocationDelegate.upload(dataType: "visits")
            LocationDelegate.upload(dataType: "locations")
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
        self.logButton.sizeToFit()
        self.reloadLogView()
    }

    func reloadLogView() {
        let logTypeToUrl = [
            LogType.App: LogUtil.AppLogsURL,
            LogType.Location: LogUtil.LocationLogsURL,
            LogType.Visit: LogUtil.VisitLogsURL
        ]
        let logType = self.currLog
        let url = logTypeToUrl[logType] ?? LogUtil.AppLogsURL

        DispatchQueue.global(qos: .background).async {
            var str: NSMutableAttributedString = NSMutableAttributedString()
            let recent = LogUtil.load(url: url, last: 500)
            if recent.isEmpty {
                str = NSMutableAttributedString(string: "(empty)", attributes: [.foregroundColor: UIColor.lightGray])
            } else {
                str = Dictionary(grouping: recent, by: { (e: LogEntry) in Calendar.current.startOfDay(for: e.time) })
                    .sorted(by: { $0.key > $1.key })
                    .flatMap({ (date: Date, logs: [LogEntry]) -> [NSMutableAttributedString] in
                        let dateHeader = ViewController.fmtDateHeader(date: date)
                        let logLines: NSMutableAttributedString = logs
                            .sorted(by: { $0.time > $1.time })
                            .map(ViewController.fmtLogEntry)
                            .reduce(NSMutableAttributedString(), { (acc, curr) in acc.append(curr); return acc })
                        return [dateHeader, logLines]
                    })
                    .reduce(NSMutableAttributedString(), { (acc, curr) in acc.append(curr); return acc })
            }

            DispatchQueue.main.async {
                if self.currLog == logType {
                    let start = CFAbsoluteTimeGetCurrent()
                    self.recentLogs.attributedText = str
                    print("done assigning recentLogs.attributedText, elapsed: \(CFAbsoluteTimeGetCurrent() - start)s")
                }
            }
        }
    }
    
    static func fmtDateHeader(date: Date) -> NSMutableAttributedString {
        let dateFmt = DateFormatter()
        dateFmt.locale = Locale(identifier: "en_US")
        dateFmt.setLocalizedDateFormatFromTemplate("yyyy-MM-dd")
        return NSMutableAttributedString(
            string: "\(dateFmt.string(from: date))\n",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.backgroundColor: UIColor.blue])
    }
  
    static func fmtLogEntry(log: LogEntry) -> NSMutableAttributedString {
        let timeFmt = DateFormatter()
        timeFmt.locale = Locale(identifier: "en_US")
        timeFmt.setLocalizedDateFormatFromTemplate("HH:mm:ss")
        let s = NSMutableAttributedString(
            string: "[\(timeFmt.string(from: log.time))] ",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.lightGray])
        if #available(iOS 13.0, *) {
            s.append(NSAttributedString(string: log.msg + "\n", attributes: [NSAttributedString.Key.foregroundColor: UIColor.label]))
        } else {
            // Fallback on earlier versions
            s.append(NSAttributedString(string: log.msg + "\n"))
        }
        return s
    }
}
