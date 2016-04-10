//
//  Tune.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import Foundation
import UIKit
import CoreData

class Tune: NSManagedObject {

    /* Database managed attributes */
    @NSManaged var id: String
    @NSManaged var source: String
    
    // Relationships
    @NSManaged var tags: [Tag]

}
