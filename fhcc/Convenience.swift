//
//  Convenience.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/07/13.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//



public func regexpMatch(string: String, #pattern: String) -> [[String]] {
    let nsstr = NSString(string: string)
    let opt = NSRegularExpressionOptions.CaseInsensitive | NSRegularExpressionOptions.DotMatchesLineSeparators
    var error: NSError?
    let regex = NSRegularExpression(pattern: pattern, options: opt, error: &error)
    if error != nil {
        NSLog("regexp pattern compile failed: \(pattern)")
        return [[]]
    }
    let range = NSMakeRange(0, nsstr.length)
    let matches: [AnyObject] = regex.matchesInString(nsstr, options: NSMatchingOptions(0), range: range)
    return matches.map { (match:AnyObject) -> [String] in
        let m = match as NSTextCheckingResult
        let num = m.numberOfRanges
        var ss: [String] = []
        for i in (0..<num) {
            ss.append( nsstr.substringWithRange(m.rangeAtIndex(i)) )
        }
        return ss
    }
}

public func getSSID() -> String? {
    let interfaces:CFArray! = CNCopySupportedInterfaces()?.takeUnretainedValue()
    if interfaces == nil { return nil }
    let if0:UnsafePointer<Void>? = CFArrayGetValueAtIndex(interfaces, 0)
    if if0 == nil { return nil }
    let interfaceName:CFStringRef = unsafeBitCast(if0!, CFStringRef.self)
    let dicRef:NSDictionary! = CNCopyCurrentNetworkInfo(interfaceName)?.takeUnretainedValue().__conversion()
    if dicRef == nil { return nil }
    let ssidObj:AnyObject? = dicRef[kCNNetworkInfoKeySSID]
    if ssidObj == nil { return nil }
    return ssidObj! as? String
}


public func isResponseJSON (response: NSHTTPURLResponse!) -> Bool {
    if response == nil { return false }
    if response.statusCode != 200 { return false }
    let contentType: AnyObject? = response.allHeaderFields["Content-Type"]
    if contentType == nil { return false }
    let x = contentType! as String
    let xa = "application/json"
    if x.substringToIndex(xa.endIndex) == xa {
        return true
    } else {
        return false
    }
}
