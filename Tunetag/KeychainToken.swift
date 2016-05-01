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
    private var _service:String
    var accessGroup:String {
        get {
            return _accessGroup
        }
    }
    private var _accessGroup:String
    var value:String? {
        get {
            if _value != nil {
                return _value
            } else {
                var valueData:NSData?
                let itemSearchError = Keychain.getSecureItem(service, accessGroup: self.accessGroup, data: &valueData)
                assert(itemSearchError == nil, itemSearchError!.description)
                if let returnData = valueData {
                    _value = String(data:returnData, encoding: NSUTF8StringEncoding)
                }
                return _value
            }
        }
        set(token) {
            let storageError = Keychain.storeSecureItem(token?.dataUsingEncoding(NSUTF8StringEncoding), service:service, accessGroup: accessGroup)
            assert(storageError == nil, storageError!.description)
            _value = token
        }
    }
    private var _value:String?
    var expirationDate:NSDate? {
        get {
            if _expirationDate != nil {
                return _expirationDate
            } else {
                var expirationData:NSData?
                let attributeSearchError = Keychain.getSecureItemAttribute(service, accessGroup: accessGroup, data: &expirationData)
                assert(attributeSearchError == nil, attributeSearchError!.description)
                if let unwrappedExpirationData = expirationData {
                    _expirationDate = NSKeyedUnarchiver.unarchiveObjectWithData(unwrappedExpirationData) as? NSDate
                } else {
                    _expirationDate = nil
                }
                return _expirationDate
            }
        }
        set(date) {
            if let unwrappedDate = date {
                let storageError = Keychain.storeSecureItemAttribute(NSKeyedArchiver.archivedDataWithRootObject(unwrappedDate), service: service, accessGroup: accessGroup)
                assert(storageError == nil, storageError!.description)
            } else {
                let storageError = Keychain.storeSecureItemAttribute(nil, service: service, accessGroup: accessGroup)
                assert(storageError == nil, storageError!.description)
            }
            _expirationDate = date
        }
    }
    private var _expirationDate:NSDate?
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
    convenience init(tokenValue:String, tokenExpirationDate:NSDate, associatedService:String, associatedAccessGroup:String) {
        self.init(service: associatedService, accessGroup:associatedAccessGroup)
        value = tokenValue
        expirationDate = tokenExpirationDate
    }
}