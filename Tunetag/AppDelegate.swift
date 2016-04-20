//
//  AppDelegate.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - Properties
    var window: UIWindow?
    var spotifyUserLoggedIn: Bool {
        get { return NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_EXPIRATION_DATE) != nil }
    }
    var spotifyTokenValid: Bool {
        get {
            if let spotifyTokenExpirationDate = NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_EXPIRATION_DATE) as? NSDate {
                // timeIntervalSicneNow is positive if the date is in the future -> user token is still valid -> return true
                return spotifyTokenExpirationDate.timeIntervalSinceNow > 0
            } else {
                return false
            }
        }
    }


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        loginLogic()
        return true
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        self.saveContext()
    }
    
    func application(application: UIApplication, openURL url: NSURL, sourceApplication: String?, annotation: AnyObject) -> Bool {
        
        // Is this a spotify auth callback?
        if sourceApplication == "com.spotify.client" {
            // Parse the URL
            let spotifyResponseURLComponents = NSURLComponents.init(URL: url, resolvingAgainstBaseURL: false)!
            if let spotifyResponseQueryItems = spotifyResponseURLComponents.queryItems {
                
                // Build a more accessible data structure from the URL query parameters
                var spotifyResponseParameters = [String:String]()
                for queryParameter in spotifyResponseQueryItems {
                    spotifyResponseParameters[queryParameter.name] = queryParameter.value
                }
                
                if spotifyResponseParameters["code"] != nil {
                    // Spotify is calling Tunetag because scopes were authorized
                    // Use the response code to get access and refresh tokens using AWS Lambda
                    let spotifyTokenRequest = AWSLambdaInvocationRequest()
                    spotifyTokenRequest.functionName = AWS_LAMBDA_GET_TOKENS_FUNCTION_NAME
                    let payload = ["code" : spotifyResponseParameters["code"]!]
                    do {
                        try spotifyTokenRequest.payload = NSJSONSerialization.aws_dataWithJSONObject(payload, options: .PrettyPrinted)
                        AWSLambda.defaultLambda().invoke(
                            spotifyTokenRequest,
                            completionHandler: {(response, error) -> Void in
                                let responseObject = response?.payloadJSONObject() as! [String:AnyObject]
                                NSUserDefaults.standardUserDefaults().setObject(responseObject["access_token"], forKey: K_SPOTIFY_ACCESS_TOKEN)
                                NSUserDefaults.standardUserDefaults().setObject(responseObject["refresh_token"], forKey: K_SPOTIFY_REFRESH_TOKEN)
                                NSUserDefaults.standardUserDefaults().setObject(NSDate.init(timeInterval: responseObject["expires_in"] as! NSTimeInterval, sinceDate: NSDate()), forKey: K_SPOTIFY_EXPIRATION_DATE)
                        })
                    } catch {
                        NSLog("Error while serializing JSON Data for AWS")
                    }
                }
            }
            return true
        } else {
            // Cannot recognize the URL. Do not open it.
            return false
        }
    }
    
    // MARK: - Spotify Utilities
    
    // Following the auth guide from https://developer.spotify.com/web-api/authorization-guide/
    // See diagram on web page for details

    func loginLogic() {
        
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.USEast1,
                                                                identityPoolId:"us-east-1:651a9480-6172-4ab5-82ce-0c8272960212")
        
        let configuration = AWSServiceConfiguration(region:.USEast1, credentialsProvider:credentialsProvider)
        
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = configuration
        
        // Need to get the Cognito ID before setting up Spotify authentication
        credentialsProvider.getIdentityId().continueWithBlock { (task: AWSTask!) -> AnyObject! in
            if (task.error != nil) {
                print("Error: " + task.error!.localizedDescription)
            }
            else {
                // Spotify login
                if !self.spotifyUserLoggedIn {
                    
                    // Create and open the spotify login URL to request access to scopes
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
                    let spotifyLoginURL = spotifyScopeRequestURLComponents.URL
                    UIApplication.sharedApplication().openURL(spotifyLoginURL!)
                } else if !self.spotifyTokenValid {
                    // Get another access token from Spotify through AWS
                    let spotifyTokenRequest = AWSLambdaInvocationRequest()
                    spotifyTokenRequest.functionName = AWS_LAMBDA_REFRESH_TOKENS_FUNCTION_NAME
                    let payload = ["refreshToken" : NSUserDefaults.standardUserDefaults().objectForKey(K_SPOTIFY_REFRESH_TOKEN) as! String]
                    do {
                        try spotifyTokenRequest.payload = NSJSONSerialization.aws_dataWithJSONObject(payload, options: .PrettyPrinted)
                        AWSLambda.defaultLambda().invoke(
                            spotifyTokenRequest,
                            completionHandler: {(response, error) -> Void in
                                let responseObject = response?.payloadJSONObject() as! [String:AnyObject]
                                NSUserDefaults.standardUserDefaults().setObject(responseObject["access_token"], forKey: K_SPOTIFY_ACCESS_TOKEN)
                                NSUserDefaults.standardUserDefaults().setObject(responseObject["refresh_token"], forKey: K_SPOTIFY_REFRESH_TOKEN)
                                NSUserDefaults.standardUserDefaults().setObject(NSDate.init(timeInterval: responseObject["expires_in"] as! NSTimeInterval, sinceDate: NSDate()), forKey: K_SPOTIFY_EXPIRATION_DATE)
                        })
                    } catch {
                        NSLog("Error while serializing JSON Data for AWS")
                    }
                }

            }
            return nil
        }
    }


    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.seantfitzgerald.Tunetag" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1]
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("Tunetag", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator = {
        // The persistent store coordinator for the application. This implementation creates and returns a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("SingleViewCoreData.sqlite")
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch {
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason

            dict[NSUnderlyingErrorKey] = error as NSError
            let wrappedError = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(wrappedError), \(wrappedError.userInfo)")
            abort()
        }
        
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        var managedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if managedObjectContext.hasChanges {
            do {
                try managedObjectContext.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                NSLog("Unresolved error \(nserror), \(nserror.userInfo)")
                abort()
            }
        }
    }

}

