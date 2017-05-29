//
//  Keychain.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/30/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

class Keychain {

    class func getSecureItem(_ service:String, accessGroup:String, data:inout Data?) -> NSError? {
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
        return errorFromKeychainStatus(errorStatus)
    }

    class func getSecureItemAttribute(_ service:String, accessGroup:String, data:inout Data?) -> NSError? {
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
        return errorFromKeychainStatus(status)
    }
    
    class func storeSecureItem(_ item:Data?, service:String, accessGroup:String) -> NSError? {
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
            let secItemSearchStatus = SecItemCopyMatching(keychainSearchQuery as CFDictionary, &attributes)
            if secItemSearchStatus == errSecItemNotFound {
                // Found no matching security item. Create one.
                return errorFromKeychainStatus(SecItemAdd(keychainUpdateDictionary as CFDictionary, nil))
            } else if secItemSearchStatus != errSecSuccess {
                return errorFromKeychainStatus(secItemSearchStatus)
            } else {
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
                    return errorFromKeychainStatus(SecItemUpdate(keychainSearchQuery as CFDictionary, keychainUpdateDictionary as CFDictionary))
                } else {
                    return NSError(domain: "Security item found, but no attributes recovered.", code: 0, userInfo: nil)
                }
            }
        } else {
            // Passed nil storage update. Remove associated security item.
            return removeSecureItem(service, accessGroup: accessGroup)
        }
    }
    
    class func storeSecureItemAttribute(_ attribute:Data?, service:String, accessGroup:String) -> NSError? {
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
            let secItemSearchError = errorFromKeychainStatus(SecItemCopyMatching(keychainSearchQuery as CFDictionary, &returnData))
            if let searchError = secItemSearchError {
                // Error finding keychain item associated with the provided attribute
                return searchError
            } else {
                if let itemData = returnData as? Data {
                    // Found a matching security item. Update it.
                    // Add the associated item data to the update dictionary
                    keychainUpdateDictionary[kSecValueData as String] = itemData as AnyObject
                    // Remove search and update parameters that cannot be used with 'SecItemUpdate'
                    keychainSearchQuery.removeValue(forKey: kSecReturnData as String)
                    keychainSearchQuery.removeValue(forKey: kSecMatchLimit as String)
                    keychainUpdateDictionary.removeValue(forKey: kSecClass as String)
                    keychainUpdateDictionary.removeValue(forKey: kSecAttrAccessGroup as String)
                    return errorFromKeychainStatus(SecItemUpdate(keychainSearchQuery as CFDictionary, keychainUpdateDictionary as CFDictionary))
                } else {
                    // Found no matching security item. Return an error
                    return NSError(domain: "Could not find associated security item", code:0, userInfo: nil)
                }
            }
        } else {
            // Passed nil storage update. Remove associated security item attribute.
            return removeSecureItemAttribute(service, accessGroup: accessGroup)
        }
    }
    
    class func removeSecureItem(_ service:String, accessGroup:String) -> NSError? {
        let keychainSearchQuery:[String:AnyObject] = [
            kSecClass as String             : kSecClassGenericPassword,
            kSecAttrService as String       : service as AnyObject,
            kSecAttrAccessGroup as String   : accessGroup as AnyObject,
            kSecMatchLimit as String        : kSecMatchLimitOne,
            kSecReturnData as String        : kCFBooleanTrue
        ]
        return errorFromKeychainStatus(SecItemDelete(keychainSearchQuery as CFDictionary))
    }
    
    class func removeSecureItemAttribute(_ service:String, accessGroup:String) -> NSError? {
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
            let errorStatus = SecItemUpdate(keychainSearchQuery as CFDictionary, keychainUpdateDictionary as CFDictionary)
            if errorStatus != errSecSuccess {
                return errorFromKeychainStatus(errorStatus)
            } else {
                return nil
            }
        } else {
            // Found no matching security item. Return an error
            return NSError(domain: "Could not find associated security item", code:0, userInfo: nil)
        }
    }
    
    fileprivate class func errorFromKeychainStatus(_ status:OSStatus) -> NSError? {
        switch status {
        case errSecSuccess:
            return nil
        case errSecUnimplemented:
            return NSError(domain: "Function or operation not implemented.", code: Int(status as Int32), userInfo: nil)
        case errSecParam:
            return NSError(domain: "One or more parameters passed to the function were not valid.", code: Int(status as Int32), userInfo: nil)
        case errSecAllocate:
            return NSError(domain: "Failed to allocate memory.", code: Int(status as Int32), userInfo: nil)
        case errSecNotAvailable:
            return NSError(domain: "No trust results are available.", code: Int(status as Int32), userInfo: nil)
        case errSecAuthFailed:
            return NSError(domain: "Authorization/Authentication failed.", code: Int(status as Int32), userInfo: nil)
        case errSecDuplicateItem:
            return NSError(domain: "The item already exists.", code: Int(status as Int32), userInfo: nil)
        case errSecItemNotFound:
            return NSError(domain: "The item cannot be found.", code: Int(status as Int32), userInfo: nil)
        case errSecInteractionNotAllowed:
            return NSError(domain: "Interaction with the Security Server is not allowed.", code: Int(status as Int32), userInfo: nil)
        case errSecDecode:
            return NSError(domain: "Unable to decode the provided data.", code: Int(status as Int32), userInfo: nil)
        default:
            return NSError(domain: "Error code not recognized: \(status)", code: Int(status as Int32), userInfo: nil)
        }

    }
}
