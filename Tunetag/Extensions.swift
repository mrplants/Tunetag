//
//  Extensions.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/20/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import Foundation

extension AWSLambdaInvocationResponse {
    func payloadJSONObject() -> AnyObject? {
        // Converts payload buffer into JSON object
        var payloadString = ""
        for characterValue in (self.payload?["data"] as! [Int]) {
            payloadString.append(Character(UnicodeScalar(characterValue)))
        }
        // Attempts to convert string into JSON object
        do {
            let awsJSONPayload = try NSJSONSerialization.JSONObjectWithData(payloadString.dataUsingEncoding(NSUTF8StringEncoding)!, options: [])
            return awsJSONPayload
        } catch {
            return nil
        }
    }
}