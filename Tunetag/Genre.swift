//
//  Genre.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import UIKit
import CoreData
import Foundation

class Genre: NSManagedObject {

    /* Database managed attributes */
    @NSManaged var name: String

    // Relationships
    @NSManaged var tags: [Tag]

}
