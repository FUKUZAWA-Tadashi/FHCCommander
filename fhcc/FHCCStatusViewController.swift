//
//  FHCCStatusViewController.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/06/23.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation
import UIKit
import CoreLocation


private let MaxLogLength = 10000
private var fhcLogView: UITextView! = nil
private var logDateFormatter: NSDateFormatter! = nil
private var initLogText = ""
public func fhcLog(log: String) {
    if logDateFormatter == nil {
        // not yet viewDidLoad
        initLogText += "[pre start] \(log)\n"
        return
    }
    let nowstr = logDateFormatter.stringFromDate(NSDate())
    dispatch_async(dispatch_get_main_queue()) {
        var text = "[\(nowstr)] \(log)\n\(fhcLogView.text)"
        if countElements(text) > MaxLogLength {
            text = text.substringToIndex(advance(text.startIndex, MaxLogLength))
        }
        fhcLogView.text = text
    }
}

class FHCCStatusViewController : UIViewController {

    @IBOutlet weak var logView: UITextView!
    @IBOutlet weak var tempIndicator: UILabel!
    @IBOutlet weak var lumiIndicator: UILabel!
    @IBOutlet weak var inoutHomeIndicator: UILabel!
    @IBOutlet weak var distanceIndicator: UILabel!

    @IBAction func refreshButtonPressed(sender: UIButton) {
        getSensorValue()
    }
    
    var sensorTimer: NSTimer!
    
    func setTempAndLumi (temp:String, lumi:String) {
        dispatch_async(dispatch_get_main_queue()) {
            self.tempIndicator.text = "温度 : \(temp)℃"
            self.lumiIndicator.text = "明るさ : \(lumi)"
        }
    }

    func showDistance(distance: CLLocationDistance) {
        var distStr: String
        if distance < 0.0 {
            distStr = "--"
        } else if distance > 1000.0 {
            distStr = String(format:"%.1fkm", distance / 1000.0)
        } else {
            distStr = String(format:"%.0fm", distance)
        }
        dispatch_async(dispatch_get_main_queue()) {
            self.distanceIndicator.text = "自宅からの距離 : \(distStr)"
        }
    }
    
    func getSensorValueViaAPI() {
        var fhcAccess = FHCAccess()
        fhcAccess.callFHCAPI("sensor/get") {
            (json:JSON!) -> () in
            if json != nil && json["result"].asString == "ok" {
                let temp = json["temp"].asString
                let tempstr = temp != nil ? String(format:"%.1f", NSString(string:temp!).doubleValue) : "--"
                let lumi = json["lumi"].asString
                let lumistr = lumi ?? "--"
                self.setTempAndLumi(tempstr, lumi: lumistr)
                fhcLog("センサー計測しました")
            } else {
                fhcLog("センサー計測失敗")
            }
        }
    }

    func getSensorValue() {
        // <div class="navigationbar_sensor">
        //   <span class="sensor_name">温度　:</span><span class="sensor_value">28.6485</span>
        //   <br />
        //   <span class="sensor_name">明るさ:</span><span class="sensor_value">25</span>
        // </div>

        var fhcAccess = FHCAccess()

        let createPageCallback = { (resultHandler: (Bool) -> ()) -> ((String, NSHTTPURLResponse) -> ()) in
            let remoconPageCallback = { (data:String, response:NSHTTPURLResponse) -> () in
                let sensor_html = regexpMatch(data, pattern: "<div\\s+class=\"navigationbar_sensor\">.*?</div>")
                if sensor_html.count > 0 && sensor_html[0].count > 0 {
                    let sensor_values = regexpMatch(sensor_html[0][0], pattern: "<span\\s+class=\"sensor_value\">([\\d.]+)</span>")
                    if sensor_values.count >= 2 {
                        let temp = sensor_values[0][1]
                        let tempstr = String(format:"%.1f", NSString(string: temp).doubleValue)
                        let lumi = sensor_values[1][1]
                        self.setTempAndLumi(tempstr, lumi: lumi)
                        resultHandler(true)
                        return
                    }
                }
                resultHandler(false)
            }
            return remoconPageCallback
        }

        let getSensorValueFromOfficialSite = { () -> () in
            let cb2 = createPageCallback { (success2: Bool) -> () in
                if success2 {
                    fhcLog("センサー値を取得しました")
                } else {
                    fhcLog("センサー計測失敗")
                }
            }
            let url_official = NSURL(scheme: "https", host: FHCState.singleton.state.fhcOfficialSite, path: "/")
            fhcAccess.getPage(url_official, cb2)
        }
        
        if FHCState.singleton.isReachableLocalFHC() {
            let cb1 = createPageCallback { (success: Bool) -> () in
                if success {
                    fhcLog("センサー計測しました")
                } else {
                    getSensorValueFromOfficialSite()
                }
            }
            let url_local = NSURL(scheme: "http", host: FHCState.singleton.state.fhcAddress, path: "/")
            fhcAccess.getPage(url_local, cb1)
        } else {
            getSensorValueFromOfficialSite()
        }
    }


    
    deinit {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self)
        //notificationCenter.removeObserver(self, name: "FHCStateChanged", object: nil)
        //notificationCenter.removeObserver(self, name: "FHCLocationStateChanged", object: nil)
        //notificationCenter.removeObserver(self, name: "distanceUpdated", object: nil)
    }


    override func viewDidLoad () {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        fhcLogView = logView
        logDateFormatter = NSDateFormatter()
        logDateFormatter.dateFormat = "MM/dd HH:mm:ss"
        logView.text = initLogText
        fhcLog("start")
        getSensorValue()
        setTimerForSensor()

        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "setTimerForSensor", name: "FHCStateChanged", object: nil)
        notificationCenter.addObserver(self, selector: "setInoutHomeLabel", name: "FHCLocationStateChanged", object: nil)
        notificationCenter.addObserver(self, selector: "distanceUpdated:", name: "distanceUpdated", object: nil)
    }

    override func didReceiveMemoryWarning () {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    
    func setTimerForSensor () {
        let intervalNum = FHCState.singleton.state.sensorUpdateInterval
        let interval = NSTimeInterval(intervalNum * 60.0)
        if sensorTimer != nil && sensorTimer.valid {
            if sensorTimer.timeInterval == interval { return }
            sensorTimer.invalidate()
        }
        if intervalNum > 0 {
            sensorTimer = NSTimer(timeInterval: interval, target: self, selector: "getSensorValue", userInfo: nil, repeats: true)
            NSRunLoop.mainRunLoop().addTimer(sensorTimer, forMode:NSDefaultRunLoopMode)
        } else {
            sensorTimer = nil
        }
    }
    

    func setInoutHomeLabel () {
        let fhcState = FHCState.singleton
        var color = UIColor.grayColor()
        let rs: CLRegionState = fhcState.currentRegionState()
        switch fhcState.fhcRegionState {
        case .Inside:
            if rs == .Inside {
                inoutHomeIndicator.text = "在宅"
                color = UIColor.greenColor()
            } else if rs == .Unknown {
                inoutHomeIndicator.text = "在宅？"
            } else {
                inoutHomeIndicator.text = "外出処理中？"
            }
        case .Outside:
            if rs == .Outside {
                inoutHomeIndicator.text = "外出中"
                color = UIColor.redColor()
            } else if rs == .Unknown {
                inoutHomeIndicator.text = "帰宅途中"
            } else {
                inoutHomeIndicator.text = "帰宅処理中？"
            }
        default:
            inoutHomeIndicator.text = "(状況不明)"
        }
        inoutHomeIndicator.backgroundColor = color
    }

    func distanceUpdated (notification: NSNotification!) {
        if notification == nil {
            showDistance(-1)
        } else {
            showDistance(notification.object as CLLocationDistance)
        }
    }

}

