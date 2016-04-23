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
    static let user = Spotify()
    private init() {} //This prevents others from using the default '()' initializer for this class.
    
    // Type methods to get the state of the Spotify session
    var loggedIn:Bool {
        get {
            // Refresh token is saved when a user first logs in.
            return NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_REFRESH_TOKEN) != nil
        }
    }
    var spotifyTokenValid: Bool {
        get {
            if !loggedIn {
                NSLog("User not logged in. No tokens available.")
                return false
            } else if let spotifyTokenExpirationDate = NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_EXPIRATION_DATE) as? NSDate {
                // timeIntervalSinceNow is positive if the date is in the future -> user token is still valid -> return true
                return spotifyTokenExpirationDate.timeIntervalSinceNow > 0
            } else {
                NSLog("ERROR: No token expiration date.")
                return false
            }
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
            ]
            spotifyScopeRequestURLComponents.host = "authorize"
            spotifyScopeRequestURLComponents.scheme = "spotify-action"
            return spotifyScopeRequestURLComponents.URL!
        }
    }
    func refreshAccessToken(callback:(error:NSError?)->Void={_ in }) {
        // Get another access token from Spotify through AWS
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
                        callback(error: nil)
                    } else {
                        callback(error: err)
                    }
            })
        } catch {
            callback(error: NSError(domain:"Error while serializing JSON Data for AWS", code: 0, userInfo: nil));
        }

    }
}
