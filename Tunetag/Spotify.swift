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
    private class var accessToken:String? {
        get {
            return NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_ACCESS_TOKEN) as? String
        }
    }
    private class var expirationDate:NSDate? {
        get {
            return NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_EXPIRATION_DATE) as? NSDate
        }
    }
    private class var refreshToken:String? {
        get {
            return NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_REFRESH_TOKEN) as? String
        }
    }
    class var authenticated:Bool {
        get {
            // Refresh token is saved when a user first logs in.
            return Spotify.refreshToken != nil
        }
    }
    class var scopesRequestURL:NSURL {
        get {
            // Create the Spotify login URL to request access to scopes
            let spotifyScopeRequestURLComponents = NSURLComponents()
            spotifyScopeRequestURLComponents.queryItems = [
                NSURLQueryItem.init(name: "client_id", value: SPOTIFY_CLIENT_ID),
                NSURLQueryItem.init(name: "response_type", value: "code"),
                NSURLQueryItem.init(name: "redirect_uri", value: SPOTIFY_AUTH_REDIRECT_URL),
                NSURLQueryItem.init(name: "scope", value: SPOTIFY_AUTH_SCOPES),
                NSURLQueryItem.init(name: "state", value: SPOTIFY_SCOPE_AUTH_STATE),
                //NSURLQueryItem.init(name: "show_dialog", value: "true")
            ]
            spotifyScopeRequestURLComponents.host = "authorize"
            spotifyScopeRequestURLComponents.scheme = "spotify-action"
            return spotifyScopeRequestURLComponents.URL!
        }
    }
    //MARK: Type Methods
    class func login(code:String, callback:(error:NSError?)->Void={_ in }) {
        // Use the response code to get access and refresh tokens using AWS Lambda
        let spotifyTokenRequest = AWSLambdaInvocationRequest()
        spotifyTokenRequest.functionName = AWS_LAMBDA_GET_TOKENS_FUNCTION_NAME
        let payload = ["code" : code]
        do {
            try spotifyTokenRequest.payload = NSJSONSerialization.aws_dataWithJSONObject(payload, options: .PrettyPrinted)
            AWSLambda.defaultLambda().invoke(
                spotifyTokenRequest,
                completionHandler: {(response, err) -> Void in
                    if err == nil {
                        let responseObject = response?.payloadJSONObject() as! [String:AnyObject]
                        NSUserDefaults.standardUserDefaults().setObject(responseObject["access_token"], forKey: K_SPOTIFY_ACCESS_TOKEN)
                        NSUserDefaults.standardUserDefaults().setObject(responseObject["refresh_token"], forKey: K_SPOTIFY_REFRESH_TOKEN)
                        NSUserDefaults.standardUserDefaults().setObject(NSDate.init(timeInterval: responseObject["expires_in"] as! NSTimeInterval, sinceDate: NSDate()), forKey: K_SPOTIFY_EXPIRATION_DATE)
                        Spotify.user.getUserData()
                        callback(error: nil)
                    } else {
                        callback(error: err)
                    }
            })
        } catch {
            callback(error: NSError(domain:"Error while serializing JSON Data for AWS", code: 0, userInfo: nil));
        }
        
    }
    private init() {
        if Spotify.authenticated {
            getUserData()
        }
    } //This prevents others from using the default '()' initializer for this class.
    
    //MARK:
    //MARK: Public Instance Variables
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
    var accessTokenValid: Bool {
        get {
            if !Spotify.authenticated {
                NSLog("User not logged in. No tokens available.")
                return false
            } else if let spotifyTokenExpirationDate = Spotify.expirationDate {
                // timeIntervalSinceNow is positive if the date is in the future -> user token is still valid -> return true
                return spotifyTokenExpirationDate.timeIntervalSinceNow > 0
            } else {
                NSLog("ERROR: No token expiration date.")
                return false
            }
        }
    }
    
    //MARK: Private Instance Variables
    private var spotifyUser:SPTUser?
    private var spotifySession:SPTSession?
    
    //MARK: Public Instance Methods
    func refreshAccessToken(callback:(error:NSError?)->Void={_ in }) {
        // Check to see if the access token is even expired.
        if accessTokenValid {
            callback(error: nil)
        } else {
            // Get another access token from Spotify through AWS.
            let spotifyTokenRequest = AWSLambdaInvocationRequest()
            spotifyTokenRequest.functionName = AWS_LAMBDA_REFRESH_TOKENS_FUNCTION_NAME
            let payload = ["refreshToken" : NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_REFRESH_TOKEN) as! String]
            do {
                try spotifyTokenRequest.payload = NSJSONSerialization.aws_dataWithJSONObject(payload, options: .PrettyPrinted)
                AWSLambda.defaultLambda().invoke(
                    spotifyTokenRequest,
                    completionHandler: {(response, err) -> Void in
                        if err == nil {
                            let responseObject = response?.payloadJSONObject() as! [String:AnyObject]
                            NSUserDefaults.standardUserDefaults().setObject(responseObject["access_token"], forKey: K_SPOTIFY_ACCESS_TOKEN)
                            NSUserDefaults.standardUserDefaults().setObject(responseObject["refresh_token"], forKey: K_SPOTIFY_REFRESH_TOKEN)
                            NSUserDefaults.standardUserDefaults().setObject(NSDate.init(timeInterval: responseObject["expires_in"] as! NSTimeInterval, sinceDate: NSDate()), forKey: K_SPOTIFY_EXPIRATION_DATE)
                            // Finished refreshing access token.
                            callback(error: nil)
                        } else {
                            callback(error:err);
                        }
                })
            } catch {
                callback(error: NSError(domain: "Error while serializing JSON Data for AWS", code: 0, userInfo: nil));
            }
        }
    }
    func getUserData(callback:()->Void={}) -> Void {
        SPTUser.requestCurrentUserWithAccessToken(NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_ACCESS_TOKEN) as! String,
                                                  callback: {(err:NSError!, obj:AnyObject!) -> Void in
            if err == nil {
                self.spotifyUser = obj as? SPTUser
                self.spotifySession = SPTSession.init(
                    userName: self.spotifyUser?.canonicalUserName,
                    accessToken: Spotify.accessToken,
                    encryptedRefreshToken: Spotify.refreshToken,
                    expirationDate: Spotify.expirationDate)
                SPTYourMusic.savedTracksForUserWithAccessToken(Spotify.accessToken, callback: {(err:NSError!, obj:AnyObject!) -> Void in
                    if err == nil {
                        let listPage = obj as! SPTListPage
                        if self.savedTracks == nil {
                            self.savedTracks = [SPTSavedTrack]()
                        }
                        self.processTrackList(listPage) { (track:SPTSavedTrack)->Void in
                            if self.savedTracks != nil && !self.savedTracks!.contains({ $0.identifier == track.identifier }) {
                                self.savedTracks?.append(track)
                            }
                        }
                        callback()
                    } else {
                        NSLog(err.description)
                    }
                })
            } else {
                NSLog(err.description)
            }
        })
    }
    
    //MARK: Private Instance Methods
    func processTrackList(listPage:SPTListPage, callback:(track:SPTSavedTrack)->Void) {
        // Recursive function to process list pages
        if let items = listPage.items as? [SPTSavedTrack] {
            for track:SPTSavedTrack in items {
                callback(track: track)
            }
            if listPage.hasNextPage {
                listPage.requestNextPageWithAccessToken(Spotify.accessToken, callback: {(err:NSError!, obj:AnyObject!) -> Void in
                    if err == nil {
                        self.processTrackList((obj as! SPTListPage), callback: callback)
                    } else {
                        NSLog(err.description)
                    }
                })
            }
        }
    }
}
