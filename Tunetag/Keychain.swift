//
//  Keychain.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/30/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

class Keychain {

    class func getSecureItem(service:String, accessGroup:String, inout data:NSData?) -> NSError? {
        let keychainSearchQuery:[String:AnyObject] = [
            kSecClass as String             : kSecClassGenericPassword,
            kSecAttrService as String       : service,
            kSecAttrAccessGroup as String   : accessGroup,
            kSecMatchLimit as String        : kSecMatchLimitOne,
            kSecReturnData as String        : kCFBooleanTrue
        ]
        var returnData:AnyObject?
        let errorStatus = SecItemCopyMatching(keychainSearchQuery as CFDictionary, &returnData)
        data = returnData as? NSData
        return errorFromKeychainStatus(errorStatus)
    }

    class func getSecureItemAttribute(service:String, accessGroup:String, inout data:NSData?) -> NSError? {
        let keychainSearchQuery:[String:AnyObject] = [
            kSecClass as String             : kSecClassGenericPassword,
            kSecAttrService as String   : service,
            kSecAttrAccessGroup as String   : accessGroup,
            kSecMatchLimit as String        : kSecMatchLimitOne,
            kSecReturnAttributes as String  : kCFBooleanTrue
        ]
        var attributes:AnyObject?
        let status = SecItemCopyMatching(keychainSearchQuery as CFDictionary, &attributes)
        if let attributesDictionary = attributes as? [String:AnyObject] {
            if let genericAttribute = attributesDictionary[kSecAttrGeneric as String] {
                data = genericAttribute as? NSData
            }
        }
        return errorFromKeychainStatus(status)
    }
    
    class func storeSecureItem(item:NSData?, service:String, accessGroup:String) -> NSError? {
        if let itemToStore = item {
            // Search for the item to see if this is an update.
            var keychainSearchQuery:[String:AnyObject] = [
                kSecClass as String             : kSecClassGenericPassword,
                kSecAttrService as String       : service,
                kSecAttrAccessGroup as String   : accessGroup,
                kSecMatchLimit as String        : kSecMatchLimitOne,
                kSecReturnAttributes as String  : kCFBooleanTrue
            ]
            // After searching, update or create the security item.
            var keychainUpdateDictionary:[String:AnyObject] = [
                kSecClass as String             : kSecClassGenericPassword,
                kSecAttrService as String       : service,
                kSecAttrAccessGroup as String   : accessGroup,
                kSecValueData as String         : itemToStore
            ]
            var attributes:AnyObject?
            // Search the keychain for the item
            let secItemSearchStatus = SecItemCopyMatching(keychainSearchQuery as CFDictionary, &attributes)
            if secItemSearchStatus == errSecItemNotFound {
                // Found no matching security item. Create one.
                return errorFromKeychainStatus(SecItemAdd(keychainUpdateDictionary, nil))
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
                    keychainSearchQuery.removeValueForKey(kSecMatchLimit as String)
                    keychainSearchQuery.removeValueForKey(kSecReturnAttributes as String)
                    keychainUpdateDictionary.removeValueForKey(kSecClass as String)
                    keychainUpdateDictionary.removeValueForKey(kSecAttrAccessGroup as String)
                    return errorFromKeychainStatus(SecItemUpdate(keychainSearchQuery, keychainUpdateDictionary))
                } else {
                    return NSError(domain: "Security item found, but no attributes recovered.", code: 0, userInfo: nil)
                }
            }
        } else {
            // Passed nil storage update. Remove associated security item.
            return removeSecureItem(service, accessGroup: accessGroup)
        }
    }
    
    class func storeSecureItemAttribute(attribute:NSData?, service:String, accessGroup:String) -> NSError? {
        if let newAttribute = attribute {
            // Search for the item
            var keychainSearchQuery:[String:AnyObject] = [
                kSecClass as String             : kSecClassGenericPassword,
                kSecAttrService as String       : service,
                kSecAttrAccessGroup as String   : accessGroup,
                kSecMatchLimit as String        : kSecMatchLimitOne,
                kSecReturnData as String        : kCFBooleanTrue
            ]
            // After searching, update the security item.
            var keychainUpdateDictionary:[String:AnyObject] = [
                kSecClass as String             : kSecClassGenericPassword,
                kSecAttrService as String       : service,
                kSecAttrAccessGroup as String   : accessGroup,
                kSecAttrGeneric as String       : newAttribute
            ]
            var returnData:AnyObject?
            let secItemSearchError = errorFromKeychainStatus(SecItemCopyMatching(keychainSearchQuery as CFDictionary, &returnData))
            if let searchError = secItemSearchError {
                // Error finding keychain item associated with the provided attribute
                return searchError
            } else {
                if let itemData = returnData as? NSData {
                    // Found a matching security item. Update it.
                    // Add the associated item data to the update dictionary
                    keychainUpdateDictionary[kSecValueData as String] = itemData
                    // Remove search and update parameters that cannot be used with 'SecItemUpdate'
                    keychainSearchQuery.removeValueForKey(kSecReturnData as String)
                    keychainSearchQuery.removeValueForKey(kSecMatchLimit as String)
                    keychainUpdateDictionary.removeValueForKey(kSecClass as String)
                    keychainUpdateDictionary.removeValueForKey(kSecAttrAccessGroup as String)
                    return errorFromKeychainStatus(SecItemUpdate(keychainSearchQuery, keychainUpdateDictionary))
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
    
    class func removeSecureItem(service:String, accessGroup:String) -> NSError? {
        let keychainSearchQuery:[String:AnyObject] = [
            kSecClass as String             : kSecClassGenericPassword,
            kSecAttrService as String       : service,
            kSecAttrAccessGroup as String   : accessGroup,
            kSecMatchLimit as String        : kSecMatchLimitOne,
            kSecReturnData as String        : kCFBooleanTrue
        ]
        return errorFromKeychainStatus(SecItemDelete(keychainSearchQuery as CFDictionary))
    }
    
    class func removeSecureItemAttribute(service:String, accessGroup:String) -> NSError? {
        // Search for the item
        let keychainSearchQuery:[String:AnyObject] = [
            kSecClass as String             : kSecClassGenericPassword,
            kSecAttrService as String       : service,
            kSecAttrAccessGroup as String   : accessGroup,
            kSecMatchLimit as String        : kSecMatchLimitOne,
            kSecReturnData as String        : kCFBooleanTrue
        ]
        // After searching, update the security item.
        var keychainUpdateDictionary:[String:AnyObject] = [
            kSecClass as String             : kSecClassGenericPassword,
            kSecAttrService as String       : service,
            kSecAttrAccessGroup as String   : accessGroup,
        ]
        var returnData:AnyObject?
        SecItemCopyMatching(keychainSearchQuery as CFDictionary, &returnData)
        if let itemData = returnData as? NSData {
            // Found a matching security item. Update it.
            // Add the associated item data to the update dictionary
            keychainUpdateDictionary[kSecValueData as String] = itemData
            let errorStatus = SecItemUpdate(keychainSearchQuery, keychainUpdateDictionary)
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
    
    private class func errorFromKeychainStatus(status:OSStatus) -> NSError? {
        switch status {
        case errSecSuccess:
            return nil
        case errSecUnimplemented:
            return NSError(domain: "Function or operation not implemented.", code: 0, userInfo: nil)
        case errSecParam:
            return NSError(domain: "One or more parameters passed to the function were not valid.", code: 0, userInfo: nil)
        case errSecAllocate:
            return NSError(domain: "Failed to allocate memory.", code: 0, userInfo: nil)
        case errSecNotAvailable:
            return NSError(domain: "No trust results are available.", code: 0, userInfo: nil)
        case errSecAuthFailed:
            return NSError(domain: "Authorization/Authentication failed.", code: 0, userInfo: nil)
        case errSecDuplicateItem:
            return NSError(domain: "The item already exists.", code: 0, userInfo: nil)
        case errSecItemNotFound:
            return NSError(domain: "The item cannot be found.", code: 0, userInfo: nil)
        case errSecInteractionNotAllowed:
            return NSError(domain: "Interaction with the Security Server is not allowed.", code: 0, userInfo: nil)
        case errSecDecode:
            return NSError(domain: "Unable to decode the provided data.", code: 0, userInfo: nil)
        default:
            return NSError(domain: "Error code not recognized: \(status)", code: 0, userInfo: nil)
        }

    }
}
