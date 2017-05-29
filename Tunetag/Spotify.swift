//
//  Spotify.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/22/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import Foundation

class Spotify {
    // This class is a singleton
    
    //MARK: Type Variables
    static var user = Spotify()
    class var scopesRequestURL:URL {
        get {
            // Create the Spotify login URL to request access to scopes
            var spotifyScopeRequestURLComponents = URLComponents()
            spotifyScopeRequestURLComponents.queryItems = [
                URLQueryItem.init(name: "client_id", value: SPOTIFY_CLIENT_ID),
                URLQueryItem.init(name: "response_type", value: "code"),
                URLQueryItem.init(name: "redirect_uri", value: SPOTIFY_AUTH_REDIRECT_URL),
                URLQueryItem.init(name: "scope", value: SPOTIFY_AUTH_SCOPES),
                URLQueryItem.init(name: "state", value: SPOTIFY_SCOPE_AUTH_STATE),
                //NSURLQueryItem.init(name: "show_dialog", value: "true")
            ]
            spotifyScopeRequestURLComponents.host = "authorize"
            spotifyScopeRequestURLComponents.scheme = "spotify-action"
            return spotifyScopeRequestURLComponents.url!
        }
    }
    //MARK: Type Methods
    class func login(_ code:String, callback:@escaping (_ error:NSError?)->Void={_ in }) {
        // Use the response code to get access and refresh tokens using AWS Lambda
        let spotifyTokenRequest = AWSLambdaInvocationRequest()
        spotifyTokenRequest?.functionName = AWS_LAMBDA_GET_TOKENS_FUNCTION_NAME
        let payload = ["code" : code]
        do {
            try spotifyTokenRequest?.payload = JSONSerialization.aws_data(withJSONObject: payload, options: .prettyPrinted)
            AWSLambda.default().invoke(
                spotifyTokenRequest!,
                completionHandler: {(response, err) -> Void in
                    if err == nil {
                        if let responseObject = response?.payloadJSONObject() as? [String:AnyObject] {
                            if let tempAccessToken = responseObject["access_token"] as? String {
                                if let tempRefreshToken = responseObject["refresh_token"] as? String {
                                    if let tempTimeInterval =  responseObject["expires_in"] as? TimeInterval {
                                        let tempExpirationDate = Date.init(timeInterval:tempTimeInterval, since: Date())
                                        // Correct expected response
                                        // Securely persist credentials
                                        // Store expiration date as an attribute of the access key
                                        Keychain.storeSecureItem(
                                            tempAccessToken.data(using: String.Encoding.utf8)!,
                                            service: SPOTIFY_ACCESS_TOKEN,
                                            accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
                                        Keychain.storeSecureItemAttribute(
                                            NSKeyedArchiver.archivedData(withRootObject: tempExpirationDate),
                                            service: SPOTIFY_ACCESS_TOKEN,
                                            accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
                                        Keychain.storeSecureItem(
                                            tempRefreshToken.data(using: String.Encoding.utf8)!,
                                            service: SPOTIFY_REFRESH_TOKEN,
                                            accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
                                    }
                                }
                            }
                        }
                        // Refresh local Spotify data with new credentials
                        Spotify.user.getUserData()
                        callback(nil)
                    } else {
                        callback(err as! NSError)
                    }
            })
        } catch {
            callback(NSError(domain:"Error while serializing JSON Data for AWS", code: 0, userInfo: nil));
        }
        
    }
    fileprivate init() {
        accessToken = KeychainToken(service: SPOTIFY_ACCESS_TOKEN, accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
        refreshToken = KeychainToken(service: SPOTIFY_REFRESH_TOKEN, accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
        if authenticated {
            getUserData()
        }
    }
    
    //MARK:
    //MARK: Public Instance Variables
    var authenticated:Bool {
        get {
            // Search keychain access for a Spotify refresh token.
            // Refresh token is saved when a user first logs in.
            return self.refreshToken.value != nil
        }
    }
    var canonicalUsername:String? {
        get {
            return spotifyUser?.canonicalUserName
        }
    }
    var displayName:String? {
        get {
            return spotifyUser?.displayName
        }
    }
    var savedTracks:[SPTSavedTrack]?
    var accessTokenExpired: Bool {
        get {
            if !authenticated {
                print("User not logged in. No tokens available.")
                return true
            } else {
                return self.accessToken.isExpired
            }
        }
    }
    
    //MARK: Private Instance Variables
    fileprivate var spotifyUser:SPTUser?
    fileprivate var accessToken:KeychainToken
    fileprivate var refreshToken:KeychainToken
    
    //MARK: Public Instance Methods
    func refreshAccessToken(_ callback:@escaping (_ error:NSError?)->Void={_ in }) {
        // Check if authenticated
        if !authenticated {
            callback(NSError(domain: "Spotify user not authenticated", code: 0, userInfo: nil))
        } else {
            // Check if the access token is  expired
            if !accessTokenExpired {
                callback(nil)
            } else {
                // Get another access token from Spotify through AWS.
                let spotifyTokenRequest = AWSLambdaInvocationRequest()
                spotifyTokenRequest?.functionName = AWS_LAMBDA_REFRESH_TOKENS_FUNCTION_NAME
                // User is authenticated, so it is safe to explicitly unwrap 'refreshToken'
                let payload = ["refreshToken" : refreshToken.value!]
                do {
                    try spotifyTokenRequest?.payload = JSONSerialization.aws_data(withJSONObject: payload, options: .prettyPrinted)
                    AWSLambda.default().invoke(
                        spotifyTokenRequest!,
                        completionHandler: {(response, err) -> Void in
                            if err == nil {
                                let responseObject = response?.payloadJSONObject() as! [String:AnyObject]
                                self.accessToken.value = responseObject["access_token"] as? String
                                self.accessToken.expirationDate = Date.init(timeInterval: responseObject["expires_in"] as! TimeInterval, since: Date())
//                                self.refreshToken.value = responseObject["refresh_token"] as? String
                                // Finished refreshing access token.
                                callback(nil)
                            } else {
                                callback(err as! NSError);
                            }
                    })
                } catch {
                    callback(NSError(domain: "Error while serializing JSON Data for AWS", code: 0, userInfo: nil));
                }
            }
        }
    }
    func getUserData(_ callback:@escaping (_ error:NSError?)->Void={_ in }) -> Void {
        checkAuthenticationAndExpirationWithRefresh({ (authRefreshError:NSError?) in
            if authRefreshError != nil {
                callback(authRefreshError)
            } else {
                // Spotify user authenticated and access token refreshed
                // Get the Spotify user attributes
                SPTUser.requestCurrentUser(withAccessToken: self.accessToken.value,
                    callback: {(userError:NSError!, obj:AnyObject!) -> Void in
                        if userError == nil {
                            self.spotifyUser = obj as? SPTUser
                            SPTYourMusic.savedTracksForUser(withAccessToken: self.accessToken.value!, callback: {(tracksError:NSError!, obj:AnyObject!) -> Void in
                                if tracksError == nil {
                                    let listPage = obj as! SPTListPage
                                    if self.savedTracks == nil {
                                        self.savedTracks = [SPTSavedTrack]()
                                    }
                                    self.processTrackList(listPage,recurse: { (track:SPTSavedTrack)->Void in
                                        if self.savedTracks != nil && !self.savedTracks!.contains(where: { $0.identifier == track.identifier }) {
                                            self.savedTracks?.append(track)
                                        }
                                    }, callback: callback)
                                } else {
                                    callback(tracksError)
                                }
                            } as! SPTRequestCallback)
                        } else {
                            callback(userError)
                        }
                } as! SPTRequestCallback)
            }
        })
    }
    
    //MARK: Private Instance Methods
    func processTrackList(_ listPage:SPTListPage, recurse:@escaping (_ track:SPTSavedTrack)->Void, callback:@escaping (_ err:NSError?) -> Void) {
        checkAuthenticationAndExpirationWithRefresh({(authError:NSError?) in
            // Spotify user authenticated and access token refreshed
            // Recursive function to process list pages
            if let items = listPage.items as? [SPTSavedTrack] {
                for track:SPTSavedTrack in items {
                    recurse(track)
                }
                if listPage.hasNextPage {
                    listPage.requestNextPage(withAccessToken: self.accessToken.value!, callback: {(err:NSError!, obj:AnyObject!) -> Void in
                        if err == nil {
                            self.processTrackList((obj as! SPTListPage), recurse: recurse, callback: callback)
                        } else {
                            callback(err)
                        }
                    } as! SPTRequestCallback)
                } else {
                    callback(nil)
                }
            }
        })
    }
    
    func checkAuthenticationAndExpirationWithRefresh(_ callback:@escaping (_ error:NSError?)->Void) {
        // Check authentication and expiration
        if !authenticated {
            callback(NSError(domain: "Spotify user not authenticated", code: 0, userInfo: nil))
        } else if accessTokenExpired {
            // Try once to refresh the access token
            self.refreshAccessToken({(err:NSError?) in
                if err != nil {
                    // Check if token is still expired
                    if !self.accessTokenExpired {
                        callback(nil)
                    } else {
                        // There's an error refreshing token data
                        callback(NSError(domain: "Spotify access token expired and cannot refresh.", code: 0, userInfo: nil))
                    }
                } else {
                    callback(err)
                }
            })
        } else {
            // Authenticated and not expired
            callback(nil)
        }
    }
}
