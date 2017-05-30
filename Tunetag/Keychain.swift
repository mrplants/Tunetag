//
//  Keychain.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/30/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

enum KeychainError: Error {
	case unimplemented
	case param
	case allocate
	case notAvailable
	case authFailed
	case duplicateItem
	case itemNotFound
	case interactionNotAllowed
	case decode
}

class Keychain {

	class func getSecureItem(_ service:String, accessGroup:String, data:inout Data?) throws {
		let keychainSearchQuery:[String:AnyObject] = [
			kSecClass as String             : kSecClassGenericPassword,
			kSecAttrService as String       : service as AnyObject,
			kSecAttrAccessGroup as String   : accessGroup as AnyObject,
			kSecMatchLimit as String        : kSecMatchLimitOne,
			kSecReturnData as String        : kCFBooleanTrue
		]
		var returnData:AnyObject?
		let errorStatus = SecItemCopyMatching(keychainSearchQuery as CFDictionary, &returnData)
		data = returnData as? Data
		try throwErrorFromKeychainStatus(errorStatus)
	}
	
	class func getSecureItemAttribute(_ service:String, accessGroup:String, data:inout Data?) throws {
		let keychainSearchQuery:[String:AnyObject] = [
			kSecClass as String             : kSecClassGenericPassword,
			kSecAttrService as String   : service as AnyObject,
			kSecAttrAccessGroup as String   : accessGroup as AnyObject,
			kSecMatchLimit as String        : kSecMatchLimitOne,
			kSecReturnAttributes as String  : kCFBooleanTrue
		]
		var attributes:AnyObject?
		let status = SecItemCopyMatching(keychainSearchQuery as CFDictionary, &attributes)
		if let attributesDictionary = attributes as? [String:AnyObject] {
			if let genericAttribute = attributesDictionary[kSecAttrGeneric as String] {
				data = genericAttribute as? Data
			}
		}
		try throwErrorFromKeychainStatus(status)
	}
	
	class func storeSecureItem(_ item:Data?, service:String, accessGroup:String) throws {
		if let itemToStore = item {
			// Search for the item to see if this is an update.
			var keychainSearchQuery:[String:AnyObject] = [
				kSecClass as String             : kSecClassGenericPassword,
				kSecAttrService as String       : service as AnyObject,
				kSecAttrAccessGroup as String   : accessGroup as AnyObject,
				kSecMatchLimit as String        : kSecMatchLimitOne,
				kSecReturnAttributes as String  : kCFBooleanTrue
			]
			// After searching, update or create the security item.
			var keychainUpdateDictionary:[String:AnyObject] = [
				kSecClass as String             : kSecClassGenericPassword,
				kSecAttrService as String       : service as AnyObject,
				kSecAttrAccessGroup as String   : accessGroup as AnyObject,
				kSecValueData as String         : itemToStore as AnyObject
			]
			var attributes:AnyObject?
			// Search the keychain for the item
			do {
				try throwErrorFromKeychainStatus(SecItemCopyMatching(keychainSearchQuery as CFDictionary, &attributes))
				// Unwrap the attributes dictionary.
				if let attributesDictionary = attributes as? [String:AnyObject] {
					// Found a matching security item. Update it.
					// Check for a generic attribute so it isn't overwritten.
					if let genericAttribute = attributesDictionary[kSecAttrGeneric as String] {
						keychainUpdateDictionary[kSecAttrGeneric as String] = genericAttribute
					}
					// Remove search and update parameters that cannot be used with 'SecItemUpdate'
					keychainSearchQuery.removeValue(forKey: kSecMatchLimit as String)
					keychainSearchQuery.removeValue(forKey: kSecReturnAttributes as String)
					keychainUpdateDictionary.removeValue(forKey: kSecClass as String)
					keychainUpdateDictionary.removeValue(forKey: kSecAttrAccessGroup as String)
					try throwErrorFromKeychainStatus(SecItemUpdate(keychainSearchQuery as CFDictionary, keychainUpdateDictionary as CFDictionary))
				} else {
					// Security item found, but no attributes recovered.
					throw KeychainError.duplicateItem
				}
			} catch KeychainError.itemNotFound {
				// Found no matching security item. Create one.
				try throwErrorFromKeychainStatus(SecItemAdd(keychainUpdateDictionary as CFDictionary, nil))
			}
		} else {
			// Passed nil storage update. Remove associated security item.
			try removeSecureItem(service, accessGroup: accessGroup)
		}
	}
	
	class func storeSecureItemAttribute(_ attribute:Data?, service:String, accessGroup:String) throws {
		if let newAttribute = attribute {
			// Search for the item
			var keychainSearchQuery:[String:AnyObject] = [
				kSecClass as String             : kSecClassGenericPassword,
				kSecAttrService as String       : service as AnyObject,
				kSecAttrAccessGroup as String   : accessGroup as AnyObject,
				kSecMatchLimit as String        : kSecMatchLimitOne,
				kSecReturnData as String        : kCFBooleanTrue
			]
			// After searching, update the security item.
			var keychainUpdateDictionary:[String:AnyObject] = [
				kSecClass as String             : kSecClassGenericPassword,
				kSecAttrService as String       : service as AnyObject,
				kSecAttrAccessGroup as String   : accessGroup as AnyObject,
				kSecAttrGeneric as String       : newAttribute as AnyObject
			]
			var returnData:AnyObject?
			try throwErrorFromKeychainStatus(SecItemCopyMatching(keychainSearchQuery as CFDictionary, &returnData))
			if let itemData = returnData as? Data {
				// Found a matching security item. Update it.
				// Add the associated item data to the update dictionary
				keychainUpdateDictionary[kSecValueData as String] = itemData as AnyObject
				// Remove search and update parameters that cannot be used with 'SecItemUpdate'
				keychainSearchQuery.removeValue(forKey: kSecReturnData as String)
				keychainSearchQuery.removeValue(forKey: kSecMatchLimit as String)
				keychainUpdateDictionary.removeValue(forKey: kSecClass as String)
				keychainUpdateDictionary.removeValue(forKey: kSecAttrAccessGroup as String)
				try throwErrorFromKeychainStatus(SecItemUpdate(keychainSearchQuery as CFDictionary, keychainUpdateDictionary as CFDictionary))
			} else {
				// Found no matching security item.
				throw KeychainError.itemNotFound
			}
		} else {
			// Passed nil storage update. Remove associated security item attribute.
			try removeSecureItemAttribute(service, accessGroup: accessGroup)
		}
	}
	
	class func removeSecureItem(_ service:String, accessGroup:String) throws {
		let keychainSearchQuery:[String:AnyObject] = [
			kSecClass as String             : kSecClassGenericPassword,
			kSecAttrService as String       : service as AnyObject,
			kSecAttrAccessGroup as String   : accessGroup as AnyObject,
			kSecMatchLimit as String        : kSecMatchLimitOne,
			kSecReturnData as String        : kCFBooleanTrue
		]
		try throwErrorFromKeychainStatus(SecItemDelete(keychainSearchQuery as CFDictionary))
	}
	
	class func removeSecureItemAttribute(_ service:String, accessGroup:String) throws {
		// Search for the item
		let keychainSearchQuery:[String:AnyObject] = [
			kSecClass as String             : kSecClassGenericPassword,
			kSecAttrService as String       : service as AnyObject,
			kSecAttrAccessGroup as String   : accessGroup as AnyObject,
			kSecMatchLimit as String        : kSecMatchLimitOne,
			kSecReturnData as String        : kCFBooleanTrue
		]
		// After searching, update the security item.
		var keychainUpdateDictionary:[String:AnyObject] = [
			kSecClass as String             : kSecClassGenericPassword,
			kSecAttrService as String       : service as AnyObject,
			kSecAttrAccessGroup as String   : accessGroup as AnyObject,
			]
		var returnData:AnyObject?
		SecItemCopyMatching(keychainSearchQuery as CFDictionary, &returnData)
		if let itemData = returnData as? Data {
			// Found a matching security item. Update it.
			// Add the associated item data to the update dictionary
			keychainUpdateDictionary[kSecValueData as String] = itemData as AnyObject
			try throwErrorFromKeychainStatus(SecItemUpdate(keychainSearchQuery as CFDictionary, keychainUpdateDictionary as CFDictionary))
		} else {
			// Found no matching security item.
			throw KeychainError.itemNotFound
		}
	}
	
	fileprivate class func throwErrorFromKeychainStatus(_ status:OSStatus) throws {
		switch status {
		case errSecSuccess:
			break
		case errSecUnimplemented:
			throw KeychainError.unimplemented
		case errSecParam:
			throw KeychainError.param
		case errSecAllocate:
			throw KeychainError.allocate
		case errSecNotAvailable:
			throw KeychainError.notAvailable
		case errSecAuthFailed:
			throw KeychainError.authFailed
		case errSecDuplicateItem:
			throw KeychainError.duplicateItem
		case errSecItemNotFound:
			throw KeychainError.itemNotFound
		case errSecInteractionNotAllowed:
			throw KeychainError.interactionNotAllowed
		case errSecDecode:
			throw KeychainError.decode
		default:
			break
		}
	}
}
