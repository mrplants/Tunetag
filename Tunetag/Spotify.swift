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
	class func login(_ code:String, callback:@escaping ()->Void={_ in }) {
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
						if let
							responseObject = response?.payloadJSONObject() as? [String:AnyObject],
							let tempAccessToken = responseObject["access_token"] as? String,
							let tempRefreshToken = responseObject["refresh_token"] as? String,
							let tempTimeInterval =  responseObject["expires_in"] as? TimeInterval
							
						{
							let tempExpirationDate = Date.init(timeInterval: tempTimeInterval, since: Date())
							// Correct expected response
							// Securely persist credentials
							// Store expiration date as an attribute of the access key
							do {
								try Keychain.storeSecureItem(
									tempAccessToken.data(using: String.Encoding.utf8)!,
									service: SPOTIFY_ACCESS_TOKEN,
									accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
								try Keychain.storeSecureItemAttribute(
									NSKeyedArchiver.archivedData(withRootObject: tempExpirationDate),
									service: SPOTIFY_ACCESS_TOKEN,
									accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
								try Keychain.storeSecureItem(
									tempRefreshToken.data(using: String.Encoding.utf8)!,
									service: SPOTIFY_REFRESH_TOKEN,
									accessGroup: SPOTIFY_WEB_API_ACCESS_GROUP)
							} catch {
								print("Error while storing Spotify credentials to Keychain.")
							}
						}
						// Refresh local Spotify data with new credentials
						Spotify.user.getUserData()
					} else {
						print("Error while invoking AWS lambda function: \((err! as NSError).userInfo)")
					}
					callback();
			})
		} catch {
			print("Error while serializing JSON Data for AWS")
			callback();
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
	func refreshAccessToken(_ callback:@escaping ()->Void={_ in }) {
		// Check if authenticated
		if !authenticated {
			print("Spotify user not authenticated")
		} else {
			// Check if the access token is  expired
			if !accessTokenExpired {
				callback()
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
								callback()
							} else {
								print("Error refreshing Spotify access token: \(err.debugDescription)");
								callback();
							}
					})
				} catch {
					print("Error while serializing JSON Data for AWS")
				}
			}
		}
	}
	func getUserData(_ callback:@escaping ()->Void={_ in }) -> Void {
		checkAuthenticationAndExpirationWithRefresh({(authCheckOkay:Bool) in
			if authCheckOkay {
				// Spotify user authenticated and access token refreshed
				// Get the Spotify user attributes
				SPTUser.requestCurrentUser(withAccessToken: self.accessToken.value,
				                           callback:
					{(userError:Error?, obj:Any?) -> Void in
						if userError == nil {
							self.spotifyUser = obj as? SPTUser
							SPTYourMusic.savedTracksForUser(withAccessToken: self.accessToken.value!, callback:
								{(tracksError:Error?, obj:Any!) -> Void in
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
										print("Error while requesting Spotify user's saved tracks.")
										callback()
									}
							})
						} else {
							print("Error while requesting current Spotify user")
							callback()
						}
				})
			}
		})
	}
	
	//MARK: Private Instance Methods
	func processTrackList(_ listPage:SPTListPage, recurse:@escaping (_ track:SPTSavedTrack)->Void, callback:@escaping () -> Void) {
		checkAuthenticationAndExpirationWithRefresh({(authCheckOkay:Bool) in
			if authCheckOkay {
				// Spotify user authenticated and access token refreshed
				// Recursive function to process list pages
				if let items = listPage.items as? [SPTSavedTrack] {
					for track:SPTSavedTrack in items {
						recurse(track)
					}
					if listPage.hasNextPage {
						listPage.requestNextPage(withAccessToken: self.accessToken.value!, callback:
							{(err:Error?, obj:Any?) -> Void in
								if err == nil {
									self.processTrackList((obj as! SPTListPage), recurse: recurse, callback: callback)
								} else {
									print("Error while requesting next page of tracks from Spotify.")
									callback()
								}
						})
					} else {
						callback()
					}
				}
			}
		})
	}
	
	func checkAuthenticationAndExpirationWithRefresh(_ callback:@escaping (_ authCheckOkay:Bool)->Void) {
		// Check authentication and expiration
		if !authenticated {
			print("Spotify user not authenticated")
			callback(false)
		} else if accessTokenExpired {
			// Try once to refresh the access token
			self.refreshAccessToken({() in
				// Check if token is still expired
				if self.accessTokenExpired {
					// Token still expired
					// There's an error refreshing token data
					print("Spotify access token expired and cannot refresh.")
					callback(false)
				} else {
					// User authenticated and token refreshed.
					callback(true)
				}
			})
		} else {
			// User authenticated and token not expired.
			callback(true)
		}
	}
}
