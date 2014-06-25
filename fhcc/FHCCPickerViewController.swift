//
//  FHCCPickerViewController.swift
//  fhcc
//
//  Created by 福澤 正 on 2014/06/22.
//  Copyright (c) 2014年 Fukuzawa Technology. All rights reserved.
//

import Foundation
import UIKit


protocol FHCCPickerViewDelegate {
    func FHCCPickerView(_ :FHCCPickerViewController!, selected: String)
}


class FHCCPickerViewController : UIViewController, UIPickerViewDelegate, UIPickerViewDataSource  {

    var pickerViewTitles: [String]!
    var selected: String?
    
    
    override func viewDidLoad () -> () {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning () -> () {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerViewTitles.count
    }
    
    func pickerView(pickerView: UIPickerView!,
        titleForRow row:Int,
        forComponent component:Int) -> String {
            return pickerViewTitles[row]
    }
    
    func pickerView(pickerView: UIPickerView!, didSelectRow row: Int, inComponent component: Int) {
        selected = pickerViewTitles[row]
    }

}
