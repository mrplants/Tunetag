//
//  TuneManagerVC.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import UIKit

class TuneManagerVC: UITableViewController {
	
	var coverArt = [UIImage?]()
	
	// MARK: - View Lifecycle
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Setup the table refresh control
		refreshControl?.addTarget(self, action: #selector(self.refreshTunes), for: .valueChanged)
		refreshTunes()
	}
	
	// MARK: Actions/Selectors
	func refreshTunes() {
		Spotify.user.getUserData { () in
			if let savedTracks = Spotify.user.savedTracks {
				self.coverArt = Array(repeating: nil, count: savedTracks.count)
			}
			self.tableView.reloadData()
			self.refreshControl?.endRefreshing()
		}
	}
	
	// MARK: Override
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
		// Assume the segue was initiated by the table view cell in order to select a single song
		let destinationVC = segue.destination as! CoverArtTransformViewController
		let selectedCell = sender as! TrackTableViewCell
		destinationVC.track = selectedCell.track
		super.prepare(for: segue, sender: sender)
	}
	
	//MARK: TableView Datasource
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		if let trackCount = Spotify.user.savedTracks?.count {
			return trackCount
		} else {
			return 0
		}
	}
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let track = Spotify.user.savedTracks?[indexPath.row]
		if let cell = tableView.dequeueReusableCell(withIdentifier: "track cell") as? TrackTableViewCell {
			setupMusicTrackCell(cell, spotifyTrack: track, indexPath: indexPath)
			return cell
		} else {
			let cell = TrackTableViewCell(style: .default,
			                              reuseIdentifier: "track cell")
			setupMusicTrackCell(cell, spotifyTrack: track, indexPath: indexPath)
			return cell
		}
		
	}
	override func numberOfSections(in tableView: UITableView) -> Int {
		return 1
	}
	
	//MARK: Utilities
	func setupMusicTrackCell(_ cell:TrackTableViewCell, spotifyTrack:SPTTrack? = nil, indexPath:IndexPath) {
		cell.track = spotifyTrack
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
	}
	
}
