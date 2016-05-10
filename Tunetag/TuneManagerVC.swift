//
//  TuneManagerVC.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import UIKit

class TuneManagerVC: UITableViewController {
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup the table refresh control
        self.refreshControl?.addTarget(self, action: #selector(self.refreshTunes), forControlEvents: .ValueChanged)
    }
        
    // MARK: Actions/Selectors
    func refreshTunes() {
        Spotify.user.getUserData { (err:NSError?) in
            assert(err == nil, err!.description)
            self.tableView.reloadData()
            self.refreshControl?.endRefreshing()
        }
    }

    //Mark: Outlets
    
}
