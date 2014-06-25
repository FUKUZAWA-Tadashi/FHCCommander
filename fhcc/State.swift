//
//  State.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/06/25.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation




class State {

    // 測位精度がこれより低ければ(大きければ)、その位置情報は捨てる
    class var ACCURACY_LIMIT: Double { return 100.0 }
    
    private let USER_DEFAULTS_KEY = "FHC_State"

    var fhcAddress: String
    var mailAddr: String
    var password: String
    var homeLatitude: Double
    var homeLongitude: Double
    var homeRegionRadius: Double
    var farRegionRadius: Double
    var homeSSID: String
    var fhcSecret: String
    var fhcOfficialSite: String
    var applianceOfOutgo: String
    var actionOfOutgo: String
    var applianceOfReturnHome: String
    var actionOfReturnHome: String
    var sensorUpdateInterval: Int
    var actionsDict: Dictionary<String, [String]>
    var judgeUsingLan: Bool
    
    class var VOICE_COMMAND: String { return "< 音声コマンド >" }
    class var ACTIONS_DICT_DEFAULTS: Dictionary<String, [String]> {
    return [
        VOICE_COMMAND : [
            "いってきます", "ただいま"
        ],
        "家電1" : [
            "すいっちおん", "でんげんきって"
        ],
        "家電2" : [
            "でんげんいれて", "すいっちおふ"
        ]
        ]
    }
    
    private let KEY_FHC_ADDRESS = "fhcAddress"
    private let KEY_MAIL_ADDR = "mailAddr"
    private let KEY_PASSWORD = "password"
    private let KEY_HOME_LATITUDE = "homeLatitude"
    private let KEY_HOME_LONGITUDE = "homeLongitude"
    private let KEY_HOME_REGION_RADIUS = "homeRegionRadius"
    private let KEY_FAR_REGION_RADIUS = "farRegionRadius"
    private let KEY_HOME_SSID = "homeSSID"
    private let KEY_FHC_SECRET = "fhcSecret"
    private let KEY_FHC_OFFICIAL_SITE = "fhcOfficialSite"
    private let KEY_APPLIANCE_OF_OUTGO = "applianceOfOutgo"
    private let KEY_ACTION_OF_OUTGO = "actionOfOutgo"
    private let KEY_APPLIANCE_OF_RETURN_HOME = "applianceOfReturnHome"
    private let KEY_ACTION_OF_RETURN_HOME = "actionOfReturnHome"
    private let KEY_SENSOR_UPDATE_INTERVAL = "sensorUpdateInterval"
    private let KEY_JUDGE_USING_LAN = "judgeUsingLan"
    private let KEY_AD_KEYS = "ad_keys"
    private let KEY_AD_VAL = "ad_val_"

    
    init () {
        fhcAddress = "fhc.local"
        mailAddr = ""
        password = ""
        homeLatitude = 0.0
        homeLongitude = 0.0
        homeRegionRadius = 20.0
        farRegionRadius = 200.0
        homeSSID = ""
        fhcSecret = ""
        fhcOfficialSite = "fhc.rti-giken.jp"
        applianceOfOutgo = ""
        actionOfOutgo = ""
        applianceOfReturnHome = ""
        actionOfReturnHome = ""
        sensorUpdateInterval = 30
        actionsDict = State.ACTIONS_DICT_DEFAULTS
        judgeUsingLan = true
    }
    
   
    func loadFromUserDefaults () -> Bool {
        var defaults = NSUserDefaults.standardUserDefaults()
        var failed = false
        func chk_load_string(key:String) -> String! {
            let x = defaults.stringForKey(key)
            if x == nil {
                NSLog("load state failed on '\(key)'")
                failed = true
            }
            return x
        }
        func chk_load_object(key:String) -> AnyObject! {
            let x: AnyObject! = defaults.objectForKey(key)
            if x == nil {
                NSLog("load state failed on '\(key)'")
                failed = true
            }
            return x
        }
        func chk_load_string_array(key:String) -> [String]! {
            let x: [AnyObject]! = defaults.stringArrayForKey(key)
            if x == nil {
                NSLog("load state failed on '\(key)'")
                failed = true
                return nil
            }
            return x as [String]
        }
        fhcAddress = chk_load_string(KEY_FHC_ADDRESS) ?? "fhc.local"
        mailAddr = chk_load_string(KEY_MAIL_ADDR) ?? ""
        password = chk_load_string(KEY_PASSWORD) ?? ""
        homeLatitude = defaults.doubleForKey(KEY_HOME_LATITUDE)
        homeLongitude = defaults.doubleForKey(KEY_HOME_LONGITUDE)
        homeRegionRadius = defaults.doubleForKey(KEY_HOME_REGION_RADIUS)
        farRegionRadius = defaults.doubleForKey(KEY_FAR_REGION_RADIUS)
        homeSSID = chk_load_string(KEY_HOME_SSID) ?? ""
        fhcSecret = chk_load_string(KEY_FHC_SECRET) ?? ""
        fhcOfficialSite = chk_load_string(KEY_FHC_OFFICIAL_SITE) ?? "fhc.rti-giken.jp"
        applianceOfOutgo = chk_load_string(KEY_APPLIANCE_OF_OUTGO) ?? ""
        actionOfOutgo = chk_load_string(KEY_ACTION_OF_OUTGO) ?? ""
        applianceOfReturnHome = chk_load_string(KEY_APPLIANCE_OF_RETURN_HOME) ?? ""
        actionOfReturnHome = chk_load_string(KEY_ACTION_OF_RETURN_HOME) ?? ""
        
        if homeRegionRadius == 0.0 { homeRegionRadius = 20.0 }
        if farRegionRadius == 0.0 { farRegionRadius = 200.0 }
        if (failed) {
            sensorUpdateInterval = 30
            judgeUsingLan = true
        } else {
            sensorUpdateInterval = defaults.integerForKey(KEY_SENSOR_UPDATE_INTERVAL)
            judgeUsingLan = defaults.boolForKey(KEY_JUDGE_USING_LAN)
        }
        
        var adict = Dictionary<String, [String]>()
        let ad_keys = chk_load_string_array(KEY_AD_KEYS)
        if ad_keys != nil {
            for (i,k) in enumerate(ad_keys!) {
                let x = chk_load_string_array(KEY_AD_VAL + "\(i)")
                if x != nil {
                    adict[k] = x
                }
            }
        }
        if adict.count > 0 { actionsDict = adict }
        
        return !failed
    }

    func saveToUserDefaults () {
        var defaults = NSUserDefaults.standardUserDefaults()

        defaults.setObject(fhcAddress, forKey: KEY_FHC_ADDRESS)
        defaults.setObject(mailAddr, forKey: KEY_MAIL_ADDR)
        defaults.setObject(password, forKey: KEY_PASSWORD)
        defaults.setDouble(homeLatitude, forKey: KEY_HOME_LATITUDE)
        defaults.setDouble(homeLongitude, forKey: KEY_HOME_LONGITUDE)
        defaults.setDouble(homeRegionRadius, forKey: KEY_HOME_REGION_RADIUS)
        defaults.setDouble(farRegionRadius, forKey: KEY_FAR_REGION_RADIUS)
        defaults.setObject(homeSSID, forKey: KEY_HOME_SSID)
        defaults.setObject(fhcSecret, forKey: KEY_FHC_SECRET)
        defaults.setObject(fhcOfficialSite, forKey: KEY_FHC_OFFICIAL_SITE)
        defaults.setObject(applianceOfOutgo, forKey: KEY_APPLIANCE_OF_OUTGO)
        defaults.setObject(actionOfOutgo, forKey: KEY_ACTION_OF_OUTGO)
        defaults.setObject(applianceOfReturnHome, forKey: KEY_APPLIANCE_OF_RETURN_HOME)
        defaults.setObject(actionOfReturnHome, forKey: KEY_ACTION_OF_RETURN_HOME)
        defaults.setInteger(sensorUpdateInterval, forKey: KEY_SENSOR_UPDATE_INTERVAL)
        defaults.setBool(judgeUsingLan, forKey: KEY_JUDGE_USING_LAN)
        let ad_keys = actionsDict.keys.array
        defaults.setObject(ad_keys.map{NSString(string:$0)}, forKey: KEY_AD_KEYS)
        for (i,k) in enumerate(ad_keys) {
            let ad_val = actionsDict[k]!.map{NSString(string:$0)}
            defaults.setObject(ad_val, forKey: KEY_AD_VAL + "\(i)")
        }

        defaults.synchronize()
    }

}