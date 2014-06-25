//
//  FHCCActionViewController.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/06/21.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation
import UIKit


@objc(FHCCActionViewController)
class FHCCActionViewController : UIViewController, UITextFieldDelegate {

    struct TagsOfView {
        static let APPLIANCE_4_OUTGO          = 10
        static let ACTION_4_OUTGO             = 11
        static let APPLIANCE_4_RETURN_HOME    = 12
        static let ACTION_4_RETURN_HOME       = 13
        static let HOME_OUTSIDE_RADIUS        = 20
        static let HOME_INSIDE_RADIUS         = 21
        static let JUDGE_USING_LAN_SWITCH     = 30
        static let LABEL_CONNECT_HOME_LAN     = 42
        static let SCROLL_VIEW                = 99
    }

    
    var pickerViewTitles: [String]!
    var buttonTag: Int = 0


    
    override func viewDidLoad () {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        fhcStateChanged()
    }
    
    override func didReceiveMemoryWarning () {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    required init(coder decoder: NSCoder) {
        pickerViewTitles = []
        buttonTag = 0
        super.init(coder: decoder)

        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.addObserver(self, selector: "fhcStateChanged", name: "FHCStateChanged", object: nil)
    }

    deinit {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        notificationCenter.removeObserver(self, name: "FHCStateChanged", object: nil)
    }
    
    
    
    func fhcStateChanged () {
        dispatch_async(dispatch_get_main_queue()) {
            let b0 = self.view.viewWithTag(TagsOfView.APPLIANCE_4_OUTGO) as UIButton
            b0.setTitle(FHCState.singleton.state.applianceOfOutgo, forState: UIControlState.Normal)
            let b1 = self.view.viewWithTag(TagsOfView.ACTION_4_OUTGO) as UIButton
            b1.setTitle(FHCState.singleton.state.actionOfOutgo, forState: UIControlState.Normal)
            let b2 = self.view.viewWithTag(TagsOfView.APPLIANCE_4_RETURN_HOME) as UIButton
            b2.setTitle(FHCState.singleton.state.applianceOfReturnHome, forState: UIControlState.Normal)
            let b3 = self.view.viewWithTag(TagsOfView.ACTION_4_RETURN_HOME) as UIButton
            b3.setTitle(FHCState.singleton.state.actionOfReturnHome, forState: UIControlState.Normal)
            let r1 = self.view.viewWithTag(TagsOfView.HOME_OUTSIDE_RADIUS) as UITextField
            r1.text = "\(Int(FHCState.singleton.state.farRegionRadius))"
            let r2 = self.view.viewWithTag(TagsOfView.HOME_INSIDE_RADIUS) as UITextField
            r2.text = "\(Int(FHCState.singleton.state.homeRegionRadius))"
            let sw = self.view.viewWithTag(TagsOfView.JUDGE_USING_LAN_SWITCH) as UISwitch
            let judgeUsingLan = FHCState.singleton.state.judgeUsingLan
            sw.setOn(judgeUsingLan, animated: false)
            let l0 = self.view.viewWithTag(TagsOfView.LABEL_CONNECT_HOME_LAN) as UILabel
            l0.textColor = judgeUsingLan ? UIColor.blackColor() : UIColor.grayColor()
        }
    }

    /*
    **
    **
    **
    */

    @IBAction func tappedButton(sender: UIButton!) {
        buttonTag = sender.tag
        switch buttonTag {
        case TagsOfView.APPLIANCE_4_OUTGO:
            pickerViewTitles = FHCState.singleton.appliancesForOutgo
        case TagsOfView.ACTION_4_OUTGO:
            pickerViewTitles = FHCState.singleton.actionsForOutgo
        case TagsOfView.APPLIANCE_4_RETURN_HOME:
            pickerViewTitles = FHCState.singleton.appliances
        case TagsOfView.ACTION_4_RETURN_HOME:
            pickerViewTitles = FHCState.singleton.actionsForReturnHome
        default:
            NSLog("unknown button pressed \(sender.tag)")
            return
        }
        // create modal segue to FHCCPickerViewController
        performSegueWithIdentifier("toPickerView", sender: sender)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject!) {
        if segue.destinationViewController is FHCCPickerViewController {
            var picker = segue.destinationViewController as FHCCPickerViewController
            picker.pickerViewTitles = pickerViewTitles
        }
    }

    @IBAction func textfieldBeginEditing(field: UITextField!) {
        let sv = field.superview!
        let y = max(sv.frame.minY + field.frame.minY - 100, 0)
        let scrollView = view.viewWithTag(TagsOfView.SCROLL_VIEW) as UIScrollView
        scrollView.setContentOffset(CGPoint(x: 0.0, y: y), animated: true)
    }
    @IBAction func textfieldEndEditing(field: UITextField!) {
        let scrollView = view.viewWithTag(TagsOfView.SCROLL_VIEW) as UIScrollView
        scrollView.setContentOffset(CGPoint(x: 0.0, y: 0), animated: true)
        let fhcState = FHCState.singleton
        if var num = field.text.toInt() {
            switch field.tag {
            case TagsOfView.HOME_OUTSIDE_RADIUS:
                num = max(30 ,max(num, Int(fhcState.state.homeRegionRadius)))
                fhcState.state.farRegionRadius = Double(num)
            case TagsOfView.HOME_INSIDE_RADIUS:
                num = max(10, min(num, Int(fhcState.state.farRegionRadius)))
                fhcState.state.homeRegionRadius = Double(num)
            default:
                NSLog("unknown text field changed: tag=\(field.tag)")
            }
            fhcState.stateChanged()
        }
    }

    override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.view.endEditing(true)
    }

    @IBAction func turnSwitch(sender: UISwitch) {
        let fhcState = FHCState.singleton
        fhcState.state.judgeUsingLan = sender.on
        fhcState.regionStateChanged()
        fhcState.stateChanged()
    }
    
    /*
    **
    **
    **
    */
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView!) -> Int {
        return 1
    }
    
    func pickerView(pickerView :UIPickerView!, numberOfRowsInComponent: Int) -> Int {
        return pickerViewTitles.count
    }
    
    func pickerView(pickerView: UIPickerView!,
        titleForRow row:Int,
        forComponent component:Int) -> String {
            return pickerViewTitles[row]
    }
    
    func pickerView(pickerView: UIPickerView!, didSelectRow row: Int, inComponent component: Int) {
        let selected = pickerViewTitles[row]
        switch buttonTag {
        case TagsOfView.APPLIANCE_4_OUTGO:
            FHCState.singleton.setApplianceForOutgo(selected)
        case TagsOfView.ACTION_4_OUTGO:
            FHCState.singleton.setActionForOutgo(selected)
        case TagsOfView.APPLIANCE_4_RETURN_HOME:
            FHCState.singleton.setApplianceForReturnHome(selected)
        case TagsOfView.ACTION_4_RETURN_HOME:
            FHCState.singleton.setActionForReturnHome(selected)
        default:
            return
        }
    }
    
    
    @IBAction func pickerViewDidSelect (segue: UIStoryboardSegue?) {
        var pickerView = segue!.sourceViewController as FHCCPickerViewController
        if let selected = pickerView.selected {
            switch buttonTag {
            case TagsOfView.APPLIANCE_4_OUTGO:
                FHCState.singleton.setApplianceForOutgo(selected)
            case TagsOfView.ACTION_4_OUTGO:
                FHCState.singleton.setActionForOutgo(selected)
            case TagsOfView.APPLIANCE_4_RETURN_HOME:
                FHCState.singleton.setApplianceForReturnHome(selected)
            case TagsOfView.ACTION_4_RETURN_HOME:
                FHCState.singleton.setActionForReturnHome(selected)
            default:
                NSLog("bug")
            }
        }
    }
    
    @IBAction func pickerViewCancelled (segue: UIStoryboardSegue?) {
    }

}
