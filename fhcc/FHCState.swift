//
//  FHCState.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/06/25.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation
import CoreLocation




class FHCState : NSObject, CLLocationManagerDelegate {
    
    class var singleton : FHCState {
        struct _Static { static let instance = FHCState() }
        return _Static.instance
    }

    var state: State

    var wifiInHome: Bool? = nil         // true when wifi connected to home LAN
    var homeRegionState: CLRegionState = .Unknown
    var farRegionState: CLRegionState = .Unknown
    var fhcRegionState: CLRegionState = .Unknown  // last commanded state

    var useReachability: Bool {
        get { return _useReachability }
        set {
            _useReachability = newValue
            if newValue {
                restartReachabilityCheck()
            } else {
                stopReachabilityCheck()
            }
        }
    }
    private var _useReachability: Bool = true
    
    override init () {
    	state = State()
    }

    
    
    
    var appliances: [String] {
    get {
        return Array(state.actionsDict.keys)
    }
    }
    var appliancesForOutgo: [String] {
    get {
        var arr = [String]()
        for k in state.actionsDict.keys {
            if k != State.VOICE_COMMAND {
                arr.append(k)
            }
        }
        return arr
    }
    }
    var actionsForOutgo: [String] {
        get { return actionsForAppliance(state.applianceOfOutgo) }
    }
    var actionsForReturnHome: [String] {
        get { return actionsForAppliance(state.applianceOfReturnHome) }
    }

    func actionsForAppliance(appliance: String) -> [String] {
        var x = [String]()
        if let actions = state.actionsDict[appliance] {
            for k in actions {
                x.append(k)
            }
        }
        return x
    }
    
    func setApplianceForOutgo(selected: String) {
        if let actions = state.actionsDict[selected] {
            state.applianceOfOutgo = selected
            state.actionOfOutgo = actions[0]  // todo: remember previous value
            stateChanged()
        }
    }
    func setActionForOutgo(selected: String) {
        if selected == state.actionOfOutgo { return }
        state.actionOfOutgo = selected
        stateChanged()
    }
    func setApplianceForReturnHome(selected: String) {
        if let actions = state.actionsDict[selected] {
            state.applianceOfReturnHome = selected
            state.actionOfReturnHome = actions[0]  // todo: remember previous value
            stateChanged()
        }
    }
    func setActionForReturnHome(selected: String) {
        if selected == state.actionOfReturnHome { return }
        state.actionOfReturnHome = selected
        stateChanged()
    }


    /*
    **
    **  get SECRET
    **
    */

    func getSecret (onSuccess: (()->())? = nil) {
        var fhcAccess = FHCAccess()
        let url = NSURL(string: "http://\(FHCState.singleton.state.fhcAddress)/edit/#webapi")
        fhcAccess.getPage(url) { /*[unowned self]*/
            (html:String, response:NSURLResponse) -> () in
            let match = regexpMatch(html, pattern: "var +g_Remocon *= *(\\{.*?\\});.*var +g_SETTING *= *(\\{.*?\\});.*var +g_Trigger *= *(\\{.*?\\});")
            if match.count > 0 && match[0].count > 2 {
                let setting = match[0][2]
                let keymatch = regexpMatch(setting, pattern: "\"webapi_apikey\" *: *\"(webapi_[0-9a-zA-Z]*)\"")
                if keymatch.count > 0 && keymatch[0].count > 1 {
                    let secret = keymatch[0][1]
                    self.state.fhcSecret = secret
                    self.stateChanged()
                    onSuccess?()
                    return
                }
            }
            fhcLog("SECRET取得失敗")
        }
    }
    
    
    /*
    **
    **  get detail thru API
    **
    */

    private var firstTimeAddToActionsDict = false
    private func addToActionsDict(key:String, val:[String]) {
        if firstTimeAddToActionsDict {
            state.actionsDict.removeAll(keepCapacity: true)
            firstTimeAddToActionsDict = false
        }
        state.actionsDict[key] = val
    }
    func getDetail () {
        firstTimeAddToActionsDict = true
        var fhcAccess = FHCAccess()
        fhcAccess.callFHCAPI("recong/list") {
            (json:JSON!)->() in
            if json == nil { return }
            if json["result"].asString != "ok" { return }
            let recogs = json["list"].asArray!.map { $0.asString! }
            self.addToActionsDict(State.VOICE_COMMAND, val: recogs)
            fhcLog("音声コマンド取得")
        }
        fhcAccess.callFHCAPI("elec/getlist") {
            (json:JSON!)->() in
            if json == nil { return }
            if json["result"].asString != "ok" { return }
            let elecs = json["list"].asArray!.map { $0.asString! }
            for elec in elecs {
                fhcAccess.callFHCAPI("elec/getactionlist", params:["elec" : elec]) {
                    (json2:JSON!)->() in
                    if json2 == nil { return }
                    if json2["result"].asString != "ok" { return }
                    let actions = json2["list"].asArray!.map { $0.asString! }
                    self.addToActionsDict(elec, val: actions)
                }
            }
            fhcLog("家電リスト取得")
        }
    }

    
    
    /*
    **
    **  location
    **
    */
    
    var locManager: CLLocationManager!
    var homeRegion: CLCircularRegion!
    var farRegion: CLCircularRegion!
    let ID_HOME_REGION = "FhccHomeRegion"
    let ID_FAR_REGION = "FhccFarRegion"
    var currentLocation: CLLocation = CLLocation(latitude: 0.0, longitude: 0.0)
    enum MeasureMode {
        case Unavailable
        case Starting
        case Recovering
        case Normal
    }
    var measureMode: MeasureMode = .Starting
    var frequentMeasureStartTime: NSDate?
    let FREQ_MEASURE_TIME = NSTimeInterval(20.0) // sec
    var _determiningHomeLoc = false


    func prepareLocationService() -> Bool {
        if locManager == nil {
            locManager = CLLocationManager()
        }
        if !CLLocationManager.isMonitoringAvailableForClass(CLRegion) {
            fhcLog("リージョン情報の取得が出来ないデバイスです")
            return false
        }
        if (CLLocationManager.authorizationStatus() == CLAuthorizationStatus.NotDetermined) {
            locManager.requestAlwaysAuthorization()
        }
        if !CLLocationManager.locationServicesEnabled() {
            fhcLog("位置情報の取得を許可されていません")
            return false
        }
        let authStat = CLLocationManager.authorizationStatus()
        if authStat != CLAuthorizationStatus.Authorized {
            fhcLog("位置情報取得の許可がありません: status=\(authStat.toRaw())")
            return false
        }
        return true
    }

    func startLocationService () -> Bool {
        measureMode = .Unavailable
        if !prepareLocationService() {
            return false
        }
        measureMode = .Starting
        frequentMeasureStart()
        return true
    }
    
    func recoverMeasurement () {
        if !prepareLocationService() {
            measureMode = .Unavailable
            return
        }
        if measureMode == .Unavailable {
            startLocationService()
            return
        }
        if measureMode != .Starting {
            measureMode = .Recovering
        }
        frequentMeasureStart()
    }

    func sleepMeasurement () {
        locManager.stopUpdatingLocation()
        restartMonitoringForRegion()        // region monitoring only
    }
    
    func frequentMeasureStart() {
        locManager.delegate = self
        locManager.desiredAccuracy = kCLLocationAccuracyBest
        locManager.distanceFilter = kCLDistanceFilterNone
        locManager.startUpdatingLocation()
        frequentMeasureStartTime = NSDate()
    }
    
    func measureModeToNormal () {
        if state.homeLatitude == 0.0 || state.homeLongitude == 0.0 || _determiningHomeLoc {
            state.homeLatitude = currentLocation.coordinate.latitude
            state.homeLongitude = currentLocation.coordinate.longitude
            state.homeRegionRadius = max(10.0, state.homeRegionRadius)
            state.farRegionRadius = max(state.homeRegionRadius + 50.0, state.farRegionRadius)
            nowAtHome()
            _determiningHomeLoc = false
            fhcLog("自宅緯度経度を設定")
        }
        let homeLocation = CLLocation(latitude: state.homeLatitude, longitude: state.homeLongitude)
        let distance = currentLocation.distanceFromLocation(homeLocation)
        notifyDistance(distance)
        setRegionState(distance)
        
        switch measureMode {
        case .Starting:
            if fhcRegionState == .Unknown {
                fhcRegionState = homeRegionState
            }
            stateChanged()
        case .Recovering:
            if fhcRegionState == .Unknown {
                fhcRegionState = homeRegionState
            }
            regionStateChanged()
        case .Normal:
            regionStateChanged()
            break
        default:
            fhcLog("bad measureMode: \(measureMode)")
            return
        }
        measureMode = .Normal
        frequentMeasureStartTime = nil
        locManager.stopUpdatingLocation()
        locManager.delegate = self
        locManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        locManager.distanceFilter = max(5.0, state.homeRegionRadius / 2.0)
        locManager.startUpdatingLocation()
        restartMonitoringForRegion()
    }
    
    func setRegionState (distance: Double) {
        homeRegionState = (distance <= state.homeRegionRadius) ? .Inside : .Outside
        farRegionState = (distance <= state.farRegionRadius) ? .Inside : .Outside
    }

    func restartMonitoringForRegion () {
        if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.Authorized {
            startLocationService()
            if CLLocationManager.authorizationStatus() != CLAuthorizationStatus.Authorized {
                return
            }
        }
        if (homeRegion != nil) {
            locManager.stopMonitoringForRegion(homeRegion)
            homeRegion = nil
        }
        if (farRegion != nil) {
            locManager.stopMonitoringForRegion(farRegion)
            farRegion = nil
        }
        if state.homeLatitude == 0.0 || state.homeLongitude == 0.0 {
            return
        }
        let homeLocation = CLLocationCoordinate2D(latitude: state.homeLatitude, longitude: state.homeLongitude)
        homeRegion = CLCircularRegion(center: homeLocation, radius: state.homeRegionRadius, identifier: ID_HOME_REGION)
        if homeRegion == nil {
            fatalError("can't create homeRegion")
        }
        farRegion = CLCircularRegion(center: homeLocation, radius: state.farRegionRadius, identifier: ID_FAR_REGION)
        if farRegion == nil {
            fatalError("can't create farRegion")
        }
        locManager.startMonitoringForRegion(homeRegion)
        locManager.startMonitoringForRegion(farRegion)
    }
    
    
    func determineHomeLocation () {
        switch measureMode {
        case .Unavailable:
            _determiningHomeLoc = true
            startLocationService()
            return
        //case .Starting, .Recovering:
        default:
            state.homeLatitude = currentLocation.coordinate.latitude
            state.homeLongitude = currentLocation.coordinate.longitude
            nowAtHome()
            frequentMeasureStart()
        }
    }

    func nowAtHome () {
        homeRegionState = .Inside
        farRegionState = .Inside
        fhcRegionState = .Inside
        wifiInHome = true
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.postNotificationName("FHCLocationStateChanged", object: self)
    }

    func locationManager (manager: CLLocationManager!, didUpdateLocations locations: Array<AnyObject>!) {
        let loc = locations.last as CLLocation
        let homeLocation = CLLocation(latitude: state.homeLatitude, longitude: state.homeLongitude)
        let distance = loc.distanceFromLocation(homeLocation)
        let distStr = String(format:"%.2f", distance)
        let accStr = String(format:"%.2f", loc.horizontalAccuracy)
        fhcLog("dist:\(distStr) acc:\(accStr)")
        if loc.horizontalAccuracy > State.ACCURACY_LIMIT {
            return
        }

        currentLocation = loc
        notifyDistance(distance)
        setRegionState(distance)

        if measureMode == .Starting && fhcRegionState == .Unknown {
            fhcRegionState = homeRegionState
        }

        regionStateChanged()
        
        if frequentMeasureStartTime != nil {
            if frequentMeasureStartTime!.timeIntervalSinceNow < -FREQ_MEASURE_TIME {
                measureModeToNormal()
            }
        }
    }

    func locationManager (manager: CLLocationManager!, didFailWithError error: NSError!) {
        fhcLog("location update failed: code=\(error.code)")
        if error.code == CLError.Denied.toRaw() {
            manager.stopUpdatingLocation()
            _determiningHomeLoc = false
        }
    }

    func locationManager (manager: CLLocationManager!, didEnterRegion region: CLRegion!) {
        switch region.identifier {
        case ID_HOME_REGION:
            homeRegionState = .Inside
            fhcLog("inside home region.")
            fallthrough
        case ID_FAR_REGION:
            farRegionState = .Inside
            fhcLog("inside far region.")
            regionStateChanged()
        default:
            fhcLog("didEnter: \(region.identifier)")
        }
    }
    
    func locationManager (manager: CLLocationManager!, didExitRegion region: CLRegion!) {
        switch region.identifier {
        case ID_FAR_REGION:
            farRegionState = .Outside
            fhcLog("outside far region.")
            fallthrough
        case ID_HOME_REGION:
            homeRegionState = .Outside
            fhcLog("outside home region.")
            regionStateChanged()
        default:
            fhcLog("didExit: \(region.identifier)")
        }
    }

    func locationManager (manager: CLLocationManager!, didDetermineState state: CLRegionState, forRegion region: CLRegion!) {
        switch region.identifier {
        case ID_HOME_REGION:
            if state == .Inside {
                homeRegionState = .Inside
                farRegionState = .Inside
                fhcLog("inside home region")
            } else if state == .Outside {
                homeRegionState = .Outside
                fhcLog("outside home region")
            }
        case ID_FAR_REGION:
            if state == .Outside {
                farRegionState = .Outside
                homeRegionState = .Outside
                fhcLog("outside far region")
            } else if state == .Inside {
                farRegionState = .Inside
                fhcLog("inside far region")
            }
        default:
            fhcLog("wrong notification in locationManager:didDetermineState:forRegion:")
        }
        regionStateChanged()
    }
    
    func locationManager (manager: CLLocationManager!, monitoringDidFailForRegion region:CLRegion!, withError error:NSError!) {
        fhcLog("location monitoring failed on region:\(region.identifier), error code:\(error.code)")
        if error.code == CLError.Denied.toRaw() {
            manager.stopUpdatingLocation()
            locManager.stopMonitoringForRegion(homeRegion)
            locManager.stopMonitoringForRegion(farRegion)
        }
    }
    
    
    func wifiStateChanged (newWifiState: Bool) {
        if wifiInHome != newWifiState {
            wifiInHome = newWifiState
            if !state.judgeUsingLan {
                return
            }
            if newWifiState {
                fhcLog("自宅LANに接続しました")
            } else {
                fhcLog("自宅LANの接続が切れました")
            }
            decideAction()
        }
    }
    func regionStateChanged () {
        checkConnectingHomeLAN()
        decideAction()
    }
    func decideAction() {
        let rs = currentRegionState()
        if fhcRegionState == .Inside && rs == .Outside {
            apartFromHome()
        } else if fhcRegionState == .Outside && rs == .Inside {
            returnToHome()
        }

        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.postNotificationName("FHCLocationStateChanged", object: self)
    }
    func currentRegionState () -> CLRegionState {
        var rs: CLRegionState = .Unknown      // .Unknown as middle point outside of home, inside of far
        if homeRegionState == .Inside {
            rs = .Inside
        } else if farRegionState == .Outside {
            rs = .Outside
        }
        if state.judgeUsingLan {
            if rs == .Inside {
                if wifiInHome == nil || !wifiInHome! {
                    rs = .Unknown
                }
            }
        }
        return rs
    }
    
    func apartFromHome () {
        if fhcRegionState == .Outside { return }
        fhcRegionState = .Outside
        fhcLog("自宅から離れました。")
        callFHCAppliance(state.applianceOfOutgo, action: state.actionOfOutgo)
    }
    func returnToHome () {
        if fhcRegionState == .Inside { return }
        fhcRegionState = .Inside
        fhcLog("帰宅しました。")
        callFHCAppliance(state.applianceOfReturnHome, action: state.actionOfReturnHome)
    }
    func callFHCAppliance (appliance: String, action: String) {
        cancelPendingAction()
        let errorHandler = { (error:NSError) -> Void in
            fhcLog("コマンド実行に失敗しました。後で再実行を試みます。")
            self.pendAction(appliance, action: action)
        }
        let fhcAccess = FHCAccess()
        if useReachability {
            if isReachableLocalFHC() {
                fhcAccess.callFHCRemoconButton("http", host: state.fhcAddress, type1: appliance, type2: action, errorHandler: errorHandler)
            } else if isReachableOfficialFHC() {
                fhcAccess.callFHCRemoconButton("https", host: state.fhcOfficialSite, type1: appliance, type2: action, errorHandler: errorHandler)
            } else {
                fhcLog("FHCにアクセス出来ません。コマンド実行を保留します。")
                pendAction(appliance, action: action)
            }
        } else {
            if state.judgeUsingLan && (wifiInHome ?? false) {
                fhcAccess.callFHCRemoconButton("http", host: state.fhcAddress, type1: appliance, type2: action, errorHandler: errorHandler)
            } else {
                fhcAccess.callFHCRemoconButton("https", host: state.fhcOfficialSite, type1: appliance, type2: action, errorHandler: errorHandler)
            }
        }
    }
    
    /*
    **
    **  Reachability
    **
    */
    
    var localFHCReachability: Reachability!
    var localFHCNetStatus: NetworkStatus = .NotReachable
    var remoteFHCOfficialReachability: Reachability!
    var remoteFHCOfficialNetStatus: NetworkStatus = .NotReachable

    func isReachableLocalFHC () -> Bool {
        let homeSSID = FHCState.singleton.state.homeSSID
        if homeSSID != "" && homeSSID != getSSID() {
            return false
        }
        return localFHCNetStatus == .ReachableViaWiFi
    }
    
    func isReachableOfficialFHC () -> Bool {
        return remoteFHCOfficialNetStatus == .ReachableViaWiFi || remoteFHCOfficialNetStatus == .ReachableViaWWAN
    }

    func startReachabilityCheck () {
        if !useReachability { return }
        if (localFHCReachability != nil) { localFHCReachability.stopNotifier() }
        localFHCReachability = Reachability(hostName: state.fhcAddress)
        localFHCReachability.alwaysReturnLocalWiFiStatus = true
        localFHCReachability.startNotifier()
        updateReachability(localFHCReachability)
        
        if (remoteFHCOfficialReachability != nil) { remoteFHCOfficialReachability.stopNotifier() }
        remoteFHCOfficialReachability = Reachability(hostName: state.fhcOfficialSite)
        remoteFHCOfficialReachability.startNotifier()
        updateReachability(remoteFHCOfficialReachability)

        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "reachabilityChanged:", name: kReachabilityChangedNotification, object: nil)
    }

    func stopReachabilityCheck () {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: kReachabilityChangedNotification, object: nil)
        if (localFHCReachability != nil) { localFHCReachability.stopNotifier() }
        if (remoteFHCOfficialReachability != nil) { remoteFHCOfficialReachability.stopNotifier() }
    }

    func restartReachabilityCheck () {
        stopReachabilityCheck()
        startReachabilityCheck()
    }
    
    func reachabilityChanged(note: NSNotification!) {
        updateReachability(note.object as Reachability)
    }

    private func netstat2str (stat: NetworkStatus) -> String {
        switch stat {
        case .ReachableViaWiFi:
            return "Reachable via WiFi"
        case .ReachableViaWWAN:
            return "Reachable via WWAN"
        default:
            return "Not Reachable"
        }
    }
    func updateReachability(reachability: Reachability) {
        let netStatus = reachability.currentReachabilityStatus()
        // let connectionRequired = reachability.connectionRequired()
        if reachability == localFHCReachability {
            localFHCNetStatus = netStatus
            fhcLog("local FHC \(netstat2str(netStatus))")
            checkConnectingHomeLAN()
        } else if reachability == remoteFHCOfficialReachability {
            remoteFHCOfficialNetStatus = netStatus
            fhcLog("official FHC \(netstat2str(netStatus))")
        }
        redoPendingAction()
    }
    
    func checkConnectingHomeLAN() -> Bool {
        if state.homeSSID == "" {
            return false
        }
        let isLAN = (getSSID() == state.homeSSID)
        wifiStateChanged(isLAN)
        return isLAN
    }

    
    /*
    **
    ** pending FHC command execution
    **
    */
    
    private var pending: [String]? = nil
    private var redoTimer: NSTimer!
    private let redoInterval: NSTimeInterval = 60.0
    private func pendAction(appliance: String, action: String) {
        pending = [appliance, action]
        savePendings()
        if redoTimer != nil && redoTimer.valid {
            redoTimer.invalidate()
        }
        redoTimer = NSTimer(timeInterval: redoInterval, target: self, selector: "redoPendingAction", userInfo: nil, repeats: false)
        NSRunLoop.mainRunLoop().addTimer(redoTimer, forMode:NSDefaultRunLoopMode)
    }
    func redoPendingAction() {
        if !isCommandPending() { return }
        let appliance = pending![0]
        let action = pending![1]
        callFHCAppliance(appliance, action: action)
    }
    func cancelPendingAction() {
        pending = nil
        savePendings()
        if redoTimer != nil && redoTimer.valid {
            redoTimer.invalidate()
        }
        redoTimer = nil
    }
    func isCommandPending() -> Bool {
        return pending != nil
    }
    
    private let KEY_PENDING_APPLIANCE = "pending_appliance"
    private let KEY_PENDING_ACTION = "pending_action"
    func savePendings() {
        var defaults = NSUserDefaults.standardUserDefaults()
        if isCommandPending() {
            defaults.setObject(pending![0], forKey: KEY_PENDING_APPLIANCE)
            defaults.setObject(pending![1], forKey: KEY_PENDING_ACTION)
        } else {
            defaults.removeObjectForKey(KEY_PENDING_APPLIANCE)
            defaults.removeObjectForKey(KEY_PENDING_ACTION)
        }
    }
    func loadPendings() {
        var defaults = NSUserDefaults.standardUserDefaults()
        let appliance = defaults.stringForKey(KEY_PENDING_APPLIANCE)
        let action = defaults.stringForKey(KEY_PENDING_ACTION)
        if appliance != nil && action != nil {
            pending = [appliance!, action!]
            redoPendingAction()
        }
    }


    /*
    **
    **
    */

    func stateChanged () {
        //NSLog("FHCState changed")
        restartMonitoringForRegion()
        restartReachabilityCheck()
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.postNotificationName("FHCStateChanged", object: self)
        saveState()
    }
    
    func notifyDistance (distance: CLLocationDistance) {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.postNotificationName("distanceUpdated", object: distance)
    }

    func saveState() {
    	state.saveToUserDefaults()
        //fhcLog("state saved")
    }
    
}
