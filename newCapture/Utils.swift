//
//  Utils.swift
//  IOSCaptureSwiftUI
//
//  Created by developer on 2021/10/20.
//

import Foundation
import ARKit

import Accelerate.vImage

// MARK: - File Name
func getCurrentTime() -> String {
    let date = Date()
    var result=""
    let calendar = Calendar.current
    let year = calendar.component(.year,from:date)
    result += String(year)
    let month = calendar.component(.month,from:date)
    if month<=9{
        result += "0"+String(month)
    }else{
        result += String(month)
    }
    let day = calendar.component(.day, from: date)
    if day<=9{
        result+="0"+String(day)
    }else{
        result+=String(day)
    }
    let hour = calendar.component(.hour, from: date)
    if hour<=9{
        result+="-0"+String(hour)
    }else{
        result+="-"+String(hour)
    }
    let minutes = calendar.component(.minute, from: date)
    if minutes<=9{
        result+="-0"+String(minutes)
    }else{
        result+="-"+String(minutes)
    }
    let second = calendar.component(.second, from: date)
    if second<=9{
        result+="-0"+String(second)
    }else{
        result+="-"+String(second)
    }
    return result
}
