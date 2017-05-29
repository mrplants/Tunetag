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
			if _value != nil {
				return _value
			} else {
				var valueData:Data?
				let itemSearchError = Keychain.getSecureItem(service, accessGroup: self.accessGroup, data: &valueData)
				assert(itemSearchError == nil || itemSearchError?.code == Int(errSecItemNotFound as Int32), itemSearchError!.description)
				if let returnData = valueData {
					_value = String(data:returnData, encoding: String.Encoding.utf8)
				}
				return _value
			}
		}
		set(token) {
			let storageError = Keychain.storeSecureItem(token?.data(using: String.Encoding.utf8), service:service, accessGroup: accessGroup)
			assert(storageError == nil, storageError!.description)
			_value = token
		}
	}
	fileprivate var _value:String?
	var expirationDate:Date? {
		get {
			if _expirationDate != nil {
				return _expirationDate
			} else {
				var expirationData:Data?
				let attributeSearchError = Keychain.getSecureItemAttribute(service, accessGroup: accessGroup, data: &expirationData)
				assert(attributeSearchError == nil, attributeSearchError!.description)
				if let unwrappedExpirationData = expirationData {
					_expirationDate = NSKeyedUnarchiver.unarchiveObject(with: unwrappedExpirationData) as? Date
				} else {
					_expirationDate = nil
				}
				return _expirationDate
			}
		}
		set(date) {
			if let unwrappedDate = date {
				let storageError = Keychain.storeSecureItemAttribute(NSKeyedArchiver.archivedData(withRootObject: unwrappedDate), service: service, accessGroup: accessGroup)
				assert(storageError == nil, storageError!.description)
			} else {
				let storageError = Keychain.storeSecureItemAttribute(nil, service: service, accessGroup: accessGroup)
				assert(storageError == nil, storageError!.description)
			}
			_expirationDate = date
		}
	}
	fileprivate var _expirationDate:Date?
	var isExpired:Bool {
		get {
			if let date = expirationDate {
				// timeIntervalSinceNow is positive if the date is in the future -> token is not expired -> return false
				return !(date.timeIntervalSinceNow > 0)
			} else {
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
