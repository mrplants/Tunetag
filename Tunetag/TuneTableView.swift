//
//  TuneTableView.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/25/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

class TuneTableView: UITableView, UITableViewDataSource {

    //MARK: Instance Variables
    //FIX: this might become a memory hog with high volumes of music coverart. Limit to a thousand or so.
    var coverArt = [UIImage?]()
    
    //MARK: Initializers
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        dataSource = self
        Spotify.user.getUserData { () in
            self.reloadData()
        }
    }
    
    //MARK: View Lifecycle
    
    //MARK: Override
    override func reloadData() {
        if let savedTracks = Spotify.user.savedTracks {
            coverArt = Array(repeating: nil, count: savedTracks.count)
        }
        super.reloadData()
    }
    
    //MARK: TableView Datasource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if let trackCount = Spotify.user.savedTracks?.count {
            return trackCount
        } else {
            return 0
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let track = Spotify.user.savedTracks?[indexPath.row]
        if let cell = tableView.dequeueReusableCell(withIdentifier: "track cell") {
            return setupMusicTrackCell(cell, spotifyTrack: track, indexPath: indexPath)
        } else {
            let cell = UITableViewCell(style: .default,
                                       reuseIdentifier: "track cell")
            return setupMusicTrackCell(cell, spotifyTrack: track, indexPath: indexPath)
        }
    }
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    //MARK: Utilities
    func setupMusicTrackCell(_ cell:UITableViewCell, spotifyTrack:SPTTrack? = nil, indexPath:IndexPath) -> UITableViewCell {
        if let track = spotifyTrack {
            cell.textLabel?.text = track.name
            if let coverImage = coverArt[indexPath.row] {
                cell.imageView?.image = coverImage
            } else {
                URLSession.shared.dataTask(
                    with: track.album.smallestCover.imageURL,
                    completionHandler: {(data, response, error)->Void in
                        if let imageData = data {
                            let coverImage = UIImage(data: imageData)
                            self.coverArt[indexPath.row] = coverImage
                            OperationQueue.main.addOperation(){
                                cell.imageView?.image = coverImage
                                cell.setNeedsLayout()
                            }
                        }
                }).resume()
            }
        }
        return cell
    }

}
