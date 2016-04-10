//
//  Tag.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import UIKit
import CoreData
import Foundation

class Tag: NSManagedObject {

    /* Database managed attributes */
    @NSManaged var id: String
    @NSManaged var name: String
    
    // Subjective features of a tag //
    @NSManaged var acousticness: Float
    @NSManaged var danceability: Float
    @NSManaged var energy: Float
    @NSManaged var instrumentalness: Float
    @NSManaged var liveness: Float
    @NSManaged var loudness: Float
    @NSManaged var speechiness: Float
    @NSManaged var tempo: Float
    @NSManaged var valence: Float
    // Subjective features of a tag //

    // Relationships
    @NSManaged var tunes: [Tune]
    @NSManaged var genres: [Genre]

}
