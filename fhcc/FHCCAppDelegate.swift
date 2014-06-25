//
//  FHCCAppDelegate.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/06/23.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation
import UIKit



@UIApplicationMain
class FHCCAppDelegate : UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: NSDictionary?) -> Bool {
        // Override point for customization after application launch.

        let FAIL_LOG_KEY = "failLog"
        var defaults = NSUserDefaults.standardUserDefaults()
        if let failLog = defaults.stringForKey(FAIL_LOG_KEY) {
            fhcLog(failLog)
            defaults.removeObjectForKey(FAIL_LOG_KEY)
        }
        setUncaughtExceptionLogSaver(FAIL_LOG_KEY)

        let fhcState = FHCState.singleton
        fhcState.state.loadFromUserDefaults()
        fhcState.startReachabilityCheck()
        fhcState.startLocationService()
        fhcState.loadPendings()

        return true
    }
    
    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }
    
    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        FHCState.singleton.saveState()
        FHCState.singleton.savePendings()
        FHCState.singleton.sleepMeasurement()
    }
    
    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        FHCState.singleton.recoverMeasurement()
        FHCState.singleton.restartReachabilityCheck()
    }
    
    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }
    
    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        FHCState.singleton.saveState()
        FHCState.singleton.savePendings()
    }

    

}
