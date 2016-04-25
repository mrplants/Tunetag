//
//  TuneManagerVC.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import UIKit

class TuneManagerVC: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    
    // MARK: - View Lifecycle
    override func viewDidLoad() {
        Spotify.user.getUserData { self.musicTable.reloadData() }
    }
    
    // MARK: Actions
    @IBAction func refreshMusicList() {
        Spotify.user.getUserData { self.musicTable.reloadData() }
    }
    
    //Mark: Outlets
    @IBOutlet weak var musicTable: UITableView!
    
    //MARK: UITableView Delegate Methods
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let trackCount = Spotify.user.savedTracks?.count {
            return trackCount
        } else {
            return 0
        }
    }
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCellWithIdentifier("track cell") {
            cell.textLabel?.text = Spotify.user.savedTracks?[indexPath.row].name
            return cell
        } else {
            let cell = UITableViewCell(style: .Default,
                                   reuseIdentifier: "track cell")
            cell.textLabel?.text = Spotify.user.savedTracks?[indexPath.row].name
            return cell
        }
    }
}
