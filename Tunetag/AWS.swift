//
//  AWS.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/24/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import Foundation

class AWS {
    static let user = AWS()
    let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.usEast1,
                                                            identityPoolId:"us-east-1:651a9480-6172-4ab5-82ce-0c8272960212")
    
    func login(_ callback:@escaping (_ task:AWSTask<AnyObject>?) -> AnyObject!) {
        
        let configuration = AWSServiceConfiguration(region:.usEast1, credentialsProvider:credentialsProvider)
        
        AWSServiceManager.default().defaultServiceConfiguration = configuration
        
        // Need to get the Cognito ID before setting up Spotify authentication
        credentialsProvider?.getIdentityId()?.continue( { (task: AWSTask!) -> AnyObject! in
            if (task.error != nil) {
                print("Error: \(task.error!.localizedDescription)")
                return task.error as AnyObject
            }
            else {
                return callback(task)
            }
        })
    }
}
