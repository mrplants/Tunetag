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
        refreshMusicList()
    }
    
    // MARK: Actions
    @IBAction func refreshMusicList() {
        Spotify.user.getUserData { (err:NSError?) in
            assert(err == nil, err!.description)
            self.tuneTable.reloadData()
        }
    }
    
    //Mark: Outlets
    @IBOutlet weak var tuneTable: TuneTableView!
    
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
        let track = Spotify.user.savedTracks?[indexPath.row]
        if let cell = tableView.dequeueReusableCellWithIdentifier("track cell") {
            return setupMusicTrackCell(cell, spotifyTrack: track)
        } else {
            let cell = UITableViewCell(style: .Default,
                                   reuseIdentifier: "track cell")
            return setupMusicTrackCell(cell, spotifyTrack: track)
        }
    }
    //MARK: Utility Methods
    func setupMusicTrackCell(cell:UITableViewCell, spotifyTrack:SPTTrack? = nil) -> UITableViewCell {
        if let track = spotifyTrack {
            cell.textLabel?.text = track.name
            cell.imageView?.image = nil
            NSURLSession.sharedSession().dataTaskWithURL(
                track.album.largestCover.imageURL,
                completionHandler: {(data, response, error)->Void in
                    if let imageData = data {
                        NSOperationQueue.mainQueue().addOperationWithBlock(){
                            cell.imageView?.image = UIImage(data: imageData)
                            cell.setNeedsLayout()
                        }
                    }
                }).resume()
        }
        return cell
    }
}
