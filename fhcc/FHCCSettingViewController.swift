//
//  FHCCSettingViewController.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/06/23.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation
import UIKit




@objc(FHCCSettingViewController)
class FHCCSettingViewController : UIViewController, UITextFieldDelegate {

    struct TagsOfView {
        static let FHC_ADDR         = 11
        static let MAIL_ADDR        = 12
        static let PASSWORD         = 13
        static let HOME_LATITUDE    = 21
        static let HOME_LONGITUDE   = 22
        static let HOME_SSID        = 23
        static let FHC_SECRET       = 24
        static let FHC_OFFICIAL_SITE = 31
        static let SENSOR_UPDATE_INTERVAL = 32
        static let SCROLL_VIEW      = 99
    }
    
    

    deinit {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: "FHCStateChanged", object: nil)
    }

    
    override func viewDidLoad () {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "readFhcState", name: "FHCStateChanged", object: nil)

        let scrollView = view.viewWithTag(TagsOfView.SCROLL_VIEW) as UIScrollView
        let bottomMostViewFrame = view.viewWithTag(TagsOfView.SENSOR_UPDATE_INTERVAL)!.frame
        let tabViewController = parentViewController as UITabBarController
        let tabBarFrame = tabViewController.tabBar.frame
        scrollView.contentSize.height = bottomMostViewFrame.maxY + tabBarFrame.height + 16
        readFhcState()
    }

    override func didReceiveMemoryWarning () {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }



    @IBAction func setHome (sender: UIButton!) {
        var alert = UIAlertController(title: "自宅設定", message: "現在の緯度経度、SSID、SECRETを 取得し設定します。", preferredStyle: .Alert)
        alert.addAction(UIAlertAction(title: "実行", style: .Default) { action in
            self.doSetHome()
            })
        alert.addAction(UIAlertAction(title: "キャンセル", style: .Cancel, handler: nil))
        presentViewController(alert, animated: true, completion: nil)
    }
    func doSetHome () {
        if let ssid = getSSID() {
            FHCState.singleton.state.homeSSID = ssid
            fhcLog("LAN SSIDを設定")
        }
        FHCState.singleton.determineHomeLocation()
        readFhcState()
        FHCState.singleton.getSecret() {
            fhcLog("SECRETを設定")
            FHCState.singleton.getDetail()
            self.readFhcState()
        }
    }

    @IBAction func textfieldBeginEditing(field: UITextField!) {
        let y = max(field.frame.minY - 100, 0)
        let scrollView = view.viewWithTag(TagsOfView.SCROLL_VIEW) as UIScrollView
        scrollView.setContentOffset(CGPoint(x: 0.0, y: y), animated: true)
    }
    
    @IBAction func textfieldEndEditing(field: UITextField!) {
        let scrollView = view.viewWithTag(TagsOfView.SCROLL_VIEW) as UIScrollView
        let btm = max(0.0, scrollView.contentSize.height - scrollView.frame.size.height)
        if scrollView.contentOffset.y > btm {
            scrollView.setContentOffset(CGPoint(x: 0.0, y: btm), animated: true)
        }
        
        var state = FHCState.singleton.state
        var changed = false
        switch field.tag {
        case TagsOfView.FHC_ADDR:
            if state.fhcAddress != field.text {
                state.fhcAddress = field.text
                changed = true
            }
        case TagsOfView.MAIL_ADDR:
            if state.mailAddr != field.text {
                state.mailAddr = field.text
                changed = true
            }
        case TagsOfView.PASSWORD:
            if state.password != field.text {
                state.password = field.text
                changed = true
            }
        case TagsOfView.HOME_LATITUDE:
            let val = NSString(string: field.text).doubleValue
            if state.homeLatitude != val {
                state.homeLatitude = val
                changed = true
            }
        case TagsOfView.HOME_LONGITUDE:
            let val = NSString(string: field.text).doubleValue
            if state.homeLongitude != val {
                state.homeLongitude = val
                changed = true
            }
        case TagsOfView.HOME_SSID:
            if state.homeSSID != field.text {
                state.homeSSID = field.text
                changed = true
            }
        case TagsOfView.FHC_SECRET:
            if state.fhcSecret != field.text {
                state.fhcSecret = field.text
                changed = true
            }
        case TagsOfView.FHC_OFFICIAL_SITE:
            if state.fhcOfficialSite != field.text {
                state.fhcOfficialSite = field.text
                changed = true
            }
        case TagsOfView.SENSOR_UPDATE_INTERVAL:
            var val = NSString(string: field.text).integerValue
            if val < 0 { val = 0 }
            if state.sensorUpdateInterval != val {
                state.sensorUpdateInterval = val
                changed = true
            }

        default:
            NSLog("unknown textfield changed \(field.tag)")
            return
        }
        if changed {
            FHCState.singleton.stateChanged()
        }
    }


    func textFieldShouldBeginEditing(textField: UITextField!) -> Bool {
        return true
    }
    func textFieldShouldReturn(field: UITextField!) -> Bool {
        self.view.endEditing(true)
        return true
    }
    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(false)
    }

    func readFhcState () {
        dispatch_async(dispatch_get_main_queue()) {
            let state = FHCState.singleton.state
            let t11 = self.view.viewWithTag(TagsOfView.FHC_ADDR) as UITextField
            t11.text = state.fhcAddress
            let t12 = self.view.viewWithTag(TagsOfView.MAIL_ADDR) as UITextField
            t12.text = state.mailAddr
            let t13 = self.view.viewWithTag(TagsOfView.PASSWORD) as UITextField
            t13.text = state.password
            let t21 = self.view.viewWithTag(TagsOfView.HOME_LATITUDE) as UITextField
            t21.text = String(format:"%.6f", state.homeLatitude)
            let t22 = self.view.viewWithTag(TagsOfView.HOME_LONGITUDE) as UITextField
            t22.text = String(format:"%.6f", state.homeLongitude)
            let t23 = self.view.viewWithTag(TagsOfView.HOME_SSID) as UITextField
            t23.text = state.homeSSID
            let t24 = self.view.viewWithTag(TagsOfView.FHC_SECRET) as UITextField
            t24.text = state.fhcSecret
            let t31 = self.view.viewWithTag(TagsOfView.FHC_OFFICIAL_SITE) as UITextField
            t31.text = state.fhcOfficialSite
            let t32 = self.view.viewWithTag(TagsOfView.SENSOR_UPDATE_INTERVAL) as UITextField
            t32.text = state.sensorUpdateInterval.description
            if state.sensorUpdateInterval > 0 {
                t32.backgroundColor = UIColor.whiteColor()
            } else {
                t32.backgroundColor = UIColor.magentaColor()
            }
        }
    }
}
