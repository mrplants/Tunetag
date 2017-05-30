//
//  KeychainToken.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/30/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import Foundation

class KeychainToken: KeychainItem {
	var service:String {
		get {
			return _service
		}
	}
	fileprivate var _service:String
	var accessGroup:String {
		get {
			return _accessGroup
		}
	}
	fileprivate var _accessGroup:String
	var value:String? {
		get {
			var _value:String?
			var valueData:Data?
			do {
				try Keychain.getSecureItem(service, accessGroup: self.accessGroup, data: &valueData)
				if let returnData = valueData {
					_value = String(data:returnData, encoding: String.Encoding.utf8)
					return _value
				}
			} catch KeychainError.itemNotFound {
				print("No token stored in keychain.")
			} catch {
				print("Keychain error while getting token.")
			}
			return nil
		}
		set(token) {
			do {
				try Keychain.storeSecureItem(token?.data(using: String.Encoding.utf8), service:service, accessGroup: accessGroup)
			} catch {
				print("Keychain error while storing token.")
			}
		}
	}
	var expirationDate:Date? {
		get {
			var _expirationDate:Date?
			var expirationData:Data?
			do {
				try Keychain.getSecureItemAttribute(service, accessGroup: accessGroup, data: &expirationData)
				if let unwrappedExpirationData = expirationData {
					_expirationDate = NSKeyedUnarchiver.unarchiveObject(with: unwrappedExpirationData) as? Date
				} else {
					_expirationDate = nil
				}
			} catch {
				print("Keychain error while getting token expiration date.")
			}
			return _expirationDate
		}
		set(date) {
			do {
				if let unwrappedDate = date {
					try Keychain.storeSecureItemAttribute(NSKeyedArchiver.archivedData(withRootObject: unwrappedDate), service: service, accessGroup: accessGroup)
				} else {
					try Keychain.storeSecureItemAttribute(nil, service: service, accessGroup: accessGroup)
				}
			} catch {
				print("Keychain error while storing token expiration date.")
			}
		}
	}
	var isExpired:Bool {
		get {
			if let date = expirationDate {
				// timeIntervalSinceNow is positive if the date is in the future -> token is not expired -> return false
				return !(date.timeIntervalSinceNow > 0)
			} else {
				// Assume the token does not expire if there is no expiration date
				return false
			}
		}
	}
	
	//MARK: Intializers
	init(service:String, accessGroup:String) {
		_service = service
		_accessGroup = accessGroup
	}
	convenience init(tokenValue:String, associatedService:String, associatedAccessGroup:String) {
		self.init(service: associatedService, accessGroup:associatedAccessGroup)
		value = tokenValue
	}
	convenience init(tokenValue:String, tokenExpirationDate:Date, associatedService:String, associatedAccessGroup:String) {
		self.init(service: associatedService, accessGroup:associatedAccessGroup)
		value = tokenValue
		expirationDate = tokenExpirationDate
	}
}
