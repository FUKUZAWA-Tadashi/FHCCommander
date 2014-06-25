//
//  FHCHTTPAccess.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/07/10.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation




class FHCAccess : NSObject,  NSURLSessionTaskDelegate {
    
    class func getURLSessionOfNoCache () -> NSURLSessionConfiguration {
        var conf = NSURLSessionConfiguration.defaultSessionConfiguration()
        conf.URLCache = nil
        return conf
    }
    class var sessionConf : NSURLSessionConfiguration {
        struct _Static { static let conf = FHCAccess.getURLSessionOfNoCache() }
        return _Static.conf
    }


    var session: NSURLSession!
    
    override init () {
        super.init()
        session = NSURLSession(configuration: FHCAccess.sessionConf, delegate: self, delegateQueue:nil)
    }


    func getPage(url: NSURL, callback: (String, NSHTTPURLResponse) -> Void, errorHandler: ((NSError)->Void)? = nil) {
        get(url, { (data1:String, response1:NSURLResponse) -> Void in
            if response1.URL?.path == "/auth" {
                self.auth(url, html:data1) {
                    (data2:String, response2:NSURLResponse!) -> Void in
                    let path2 = response2?.URL?.path
                    if path2 == nil || path2 == "/auth" {
                        fhcLog("\(url.scheme!)://\(url.host!) ログイン失敗")
                    } else {
                        fhcLog("\(url.scheme!)://\(url.host!) ログイン成功")
                        callback(data2, response2 as NSHTTPURLResponse)
                    }
                }
            } else {
                callback(data1, response1 as NSHTTPURLResponse)
            }
        }, errorHandler)
    }
    
    func postPage(url: NSURL, postStr: String, callback: (String, NSHTTPURLResponse) -> Void, errorHandler: ((NSError)->Void)? = nil) {
        post(url, postStr: postStr, { (data1:String, response1:NSURLResponse) -> Void in
            if response1.URL?.path == "/auth" {
                self.auth(url, html:data1, { (data2:String, response2:NSURLResponse!) -> Void in
                    let path2 = response2?.URL?.path
                    if path2 == nil || path2 == "/auth" {
                        fhcLog("\(url.scheme!)://\(url.host!) ログイン失敗")
                    } else {
                        fhcLog("\(url.scheme!)://\(url.host!) ログイン成功")
                        callback(data2, response2 as NSHTTPURLResponse)
                    }
                }, errorHandler)
            } else {
                callback(data1, response1 as NSHTTPURLResponse)
            }
        }, errorHandler)
    }
    

    func auth(url: NSURL, html: String, callback:(String,NSURLResponse!)->Void, errorHandler: ((NSError)->Void)? = nil) {
        let m_form = regexpMatch(html, pattern: "<form([^>]*)>(.*?)</form>")
        if m_form.count < 1 {
            fhcLog("auth form mismatch")
            callback("", nil)
            return
        }
        let m_action = regexpMatch(m_form[0][1], pattern: "action=\"(.*?)\"")
        let action = m_action[0][1]
        let m_method = regexpMatch(m_form[0][1], pattern: "method=\"(.*?)\"")
        let method = m_method[0][1].lowercaseString
        let m_input = regexpMatch(m_form[0][2], pattern: "<input(.*?)>")
        var inputDict = [String:String]()   // [name : value]
        for inp in m_input {
            let attribs = inp[0]
            let m_type = regexpMatch(attribs, pattern: "type=\"(.*?)\"")
            if m_type.count > 0 {
                let type = m_type[0][1].lowercaseString
                if type != "submit" {
                    let m_name = regexpMatch(attribs, pattern: "name=\"(.*?)\"")
                    if m_name.count > 0 {
                        let name = m_name[0][1]
                        let m_value = regexpMatch(attribs, pattern: "value=\"(.*?)\"")
                        let value = m_value.count > 0 ? m_value[0][1] : ""
                        inputDict[name] = value
                    }
                }
            }
        }
        
        let idOpt: String? = FHCState.singleton.state.mailAddr.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
        inputDict["id"] = idOpt
        let pwOpt: String? = FHCState.singleton.state.password.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)
        inputDict["password"] = pwOpt?.stringByReplacingOccurrencesOfString("&", withString: "%26")
        
        let actionUrlStr = "\(url.scheme!)://\(url.host!)\(action)"
        let actionUrl = NSURL.URLWithString(actionUrlStr)
        if actionUrl == nil {
            fhcLog("bad url: \(actionUrlStr)")
            callback("", nil)
            return
        }
        // NSURL(scheme:host:path:) はpath中の#をエスケープしてしまう
        var pairs = [String]()
        for (name,value) in inputDict {
            pairs.append(name + "=" + value)
        }
        let content = "&".join(pairs)
        
        switch method.lowercaseString {
        case "get":
            get(actionUrl, callback: callback, errorHandler: errorHandler)
        case "post":
            post(actionUrl, postStr: content, callback: callback, errorHandler: errorHandler)
        default:
            fhcLog("unknown method '\(method)' on auth page")
            callback("", nil)
        }
    }

    // callFHCAPI("elec/action", params: ["elec":"家電名", "action":"操作名"]) { ... }
    // callFHCAPI("sensor/get") { ... }
    // can use under local connection
    func callFHCAPI (apiPath: String, params: [String:String], callback: ((JSON!)->Void)? = nil, errorHandler: ((NSError)->Void)? = nil) {
        var dic = params
        dic["webapi_apikey"] = FHCState.singleton.state.fhcSecret
        let queryStr = makeQueryString(dic)
        let path = "/api/\(apiPath)?\(queryStr)"
        let url = NSURL(scheme: "http", host: FHCState.singleton.state.fhcAddress, path: path)
        getPage(url, { (data:String, response:NSHTTPURLResponse) -> Void in
            if !isResponseJSON(response) {
                NSLog(response.description)
                fhcLog("API呼び出し失敗")
                if errorHandler != nil {
                    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable, userInfo: ["FHCC":"API call failed"])
                    errorHandler!(error)
                } else {
                    callback?(nil)
                }
                return
            }
            let json = JSON.parse(data)
            if json["result"].asString != "ok" {
                let errCode = json["code"].asString!
                let errMess = json["message"].asString!
                fhcLog("APIエラー:\(errCode) \(errMess)")
                if errorHandler != nil {
                    let info: [NSObject : AnyObject] = [
                        "FHCC_JSON_ERRORCODE" : errCode,
                        "FHCC_JSON_ERRMESSAGE" : errMess
                    ]
                    let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: info)
                    errorHandler!(error)
                }
            }
            callback?(json)
        }, errorHandler)
    }
    func callFHCAPI (apiPath: String, callback: ((JSON!)->Void)? = nil, errorHandler: ((NSError)->Void)? = nil) {
        callFHCAPI(apiPath, params: [:], callback: callback, errorHandler: errorHandler)
    }

    // ["key":"value", "key2":"value2"]  -->  "key=value&key2=value2"
    func makeQueryString (params: [String:String]) -> String {
        if params.count < 1 { return "" }
        var pairs: [String] = []
        for (key,value) in params {
            pairs.append("\(key)=\(value)")
        }
        return "&".join(pairs)
    }
    
    // can use under local connection
    func callVoiceCommand (command: String, callback: ((JSON!)->Void)? = nil, errorHandler: ((NSError)->Void)? = nil) {
        callFHCAPI("recong/firebystring", params: ["str":command], callback: callback, errorHandler: errorHandler)
    }

    // callFHCRemoconButton("http", host: "192.168.99.999", type1: "テレビ", type2: "入力切替")
    // can use under local or internet connection
    func callFHCRemoconButton (scheme: String, host: String, type1: String, type2: String, errorHandler: ((NSError)->Void)? = nil) {
        if type1 == State.VOICE_COMMAND {
            callVoiceCommand(type2, { (json: JSON!) -> Void in
                if json["result"].asString == "ok" {
                    fhcLog("音声コマンド実行")
                }
            }, errorHandler)
        }
        let remoconPageUrl = NSURL(scheme: scheme, host: host, path: "/")
        getPage(remoconPageUrl, {
            (data_r:String, response_r:NSHTTPURLResponse) -> Void in
            if response_r.URL?.path != "/remocon" {
                fhcLog("リモコンページへのアクセス失敗")
                return
            }
            let refererURL = response_r.URL?.absoluteString
            self.session.configuration.HTTPAdditionalHeaders = [:]
            if refererURL != nil {
                self.session.configuration.HTTPAdditionalHeaders!["Referer"] = refererURL!
            }
            self.session.configuration.HTTPAdditionalHeaders!["Content-Type"] = "application/x-www-form-urlencoded"
            let queryStr = self.makeQueryString(["type1":type1, "type2":type2])
            let path = "/remocon/fire/bytype"
            let url = NSURL(scheme: scheme, host: host, path: path)
            self.postPage(url, postStr: queryStr, {
                (data:String, response:NSHTTPURLResponse) -> Void in
                if response.URL?.path != path {
                    NSLog("remocon button URL goes --> \(response.URL?.path)")
                    let err = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadURL, userInfo: ["FHCC_REMOCON_PATH":(response.URL?.path ?? "nil")])
                    errorHandler?(err)
                    return
                }
                
                if !isResponseJSON(response) {
                    NSLog(response.description)
                    NSLog(data)
                    fhcLog("リモコン操作失敗")
                    if errorHandler != nil {
                        let info: [NSObject:AnyObject] = [
                            "FHCC" : "remocon control failed",
                            "FHCC_RESPONSE" : response.description,
                            "FHCC_DATA" : data
                        ]
                        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorResourceUnavailable, userInfo: info)
                        errorHandler!(error)
                    }
                    return
                }
                let json = JSON.parse(data)
                if json["result"].asString != "ok" {
                    let errCode = json["code"].asString!
                    let errMess = json["message"].asString!
                    fhcLog("APIエラー:\(errCode) \(errMess)")
                    if errorHandler != nil {
                        let info: [NSObject : AnyObject] = [
                            "FHCC_JSON_ERRORCODE" : errCode,
                            "FHCC_JSON_ERRMESSAGE" : errMess
                        ]
                        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse, userInfo: info)
                        errorHandler!(error)
                    }
                } else {
                    fhcLog("リモコン操作実行")
                }
            }, errorHandler)
        }, errorHandler)
    }
    
    

    
    
    /**
    **  low level access funcs
    **/
    
    func get (url: NSURL, callback:(String,NSURLResponse)->Void, errorHandler:((NSError)->Void)? = nil) {
        var task = session.dataTaskWithURL(url) {
            (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
            if error != nil {
                if errorHandler != nil {
                    errorHandler!(error)
                } else {
                    fhcLog("error on get \(url): \(error)")
                }
            } else {
                let str: String = NSString(data:data, encoding:NSUTF8StringEncoding)
                callback(str, response)
            }
        }
        task.resume()
    }
    
    func post (url: NSURL, postStr: String, callback:(String,NSURLResponse)->Void, errorHandler:((NSError)->Void)? = nil) {
        var request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        request.HTTPBody = postStr.dataUsingEncoding(NSUTF8StringEncoding)
        var task = session.dataTaskWithRequest(request) {
            (data: NSData!, response: NSURLResponse!, error: NSError!) -> Void in
            if error != nil {
                if errorHandler != nil {
                    errorHandler!(error)
                } else {
                    fhcLog("error on post \(url): \(error)")
                }
            } else {
                let str: String = NSString(data:data, encoding:NSUTF8StringEncoding)
                callback(str, response)
            }
        }
        task.resume()
    }

    
    
    /**
    **  protocol NSURLSessionTaskDelegate
    **/

    func URLSession(session: NSURLSession!, task: NSURLSessionTask, didCompleteWithError error: NSError!) {
        NSLog("task:didCompleteWithError: \(error)")
    }

    func URLSession(session: NSURLSession!,
        task: NSURLSessionTask!,
        didReceiveChallenge challenge: NSURLAuthenticationChallenge!,
        completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
            NSLog("task:didReceiveChallenge")
    }
    
    func URLSession(session: NSURLSession!,
        task: NSURLSessionTask!,
        didSendBodyData bytesSent: Int64,
        totalBytesSent: Int64,
        totalBytesExpectedToSend: Int64) {
            //NSLog("task:didSendBodyData bytesSent=\(bytesSent) totalBytesSent=\(totalBytesSent) totalBytesExpectedToSend=\(totalBytesExpectedToSend)")
    }
    
    func URLSession(session: NSURLSession!,
        task: NSURLSessionTask!,
        needNewBodyStream completionHandler: ((NSInputStream!) -> Void)!) {
            NSLog("task:needNewBodyStream")
    }
    
    func URLSession(session: NSURLSession!,
        task: NSURLSessionTask!,
        willPerformHTTPRedirection response: NSHTTPURLResponse!,
        newRequest request: NSURLRequest!,
        completionHandler: ((NSURLRequest!) -> Void)!) {
            //NSLog("task:willPerformHTTPRedirection")
            // assert: 300 <= response.statusCode <= 307

            //let statusStr = NSHTTPURLResponse.localizedStringForStatusCode(response.statusCode)
            //let headerStr = "\(response.allHeaderFields)"
            //NSLog("\(response.statusCode) \(statusStr)")
            //NSLog(headerStr)
            //NSLog(request.HTTPMethod)
            completionHandler?(request)
    }

    /**
    **  protocol NSURLSessionDelegate
    **/
    
    func URLSession(session: NSURLSession!, didBecomeInvalidWithError error: NSError!) {
        NSLog("didBecomeInvalidWithError: \(error)")
    }
    
    func URLSession(session: NSURLSession!, didReceiveChallenge challenge: NSURLAuthenticationChallenge!,
        completionHandler: ((NSURLSessionAuthChallengeDisposition, NSURLCredential!) -> Void)!) {
            // NSLog("didReceiveChallenge: \(challenge)")
            if challenge.previousFailureCount > 1 { return }
            let credential = NSURLCredential(
                user: FHCState.singleton.state.mailAddr,
                password: FHCState.singleton.state.password,
                persistence: .ForSession)
            completionHandler(.UseCredential, credential)
    }

    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession!) {
            NSLog("URLSessionDidFinishEventsForBackgroundURLSession")
    }

    
}
