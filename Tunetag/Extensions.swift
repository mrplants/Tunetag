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
		for characterValue in ((self.payload as! NSDictionary)["data"] as! NSArray) {
			payloadString.append(Character(UnicodeScalar(characterValue as! Int)!))
		}
		// Attempts to convert string into JSON object
		do {
			let awsJSONPayload = try JSONSerialization.jsonObject(with: payloadString.data(using: String.Encoding.utf8)!, options: [])
			return awsJSONPayload as AnyObject
		} catch {
			return nil
		}
	}
}

extension CFString {
	var voidPointerCString:UnsafeRawPointer {
		get{
			return UnsafeRawPointer(CFStringGetCStringPtr(self, CFStringBuiltInEncodings.UTF8.rawValue))
		}
	}
}
