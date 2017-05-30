//
//  CoverArtTransformViewController.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 5/29/17.
//  Copyright © 2017 Sean Fitzgerald. All rights reserved.
//

import UIKit

class CoverArtTransformViewController: UIViewController, SPTAudioStreamingDelegate, SPTAudioStreamingPlaybackDelegate {
	
	var _track:SPTTrack?
	var track:SPTTrack?
	var player:SPTAudioStreamingController = SPTAudioStreamingController.sharedInstance()
	var bridgingAudioController:BridgingAudioController = BridgingAudioController()
	
	@IBOutlet weak var coverArtLoadingIndicator: UIActivityIndicatorView!
	@IBOutlet weak var playPauseButton: UIButton!
	@IBOutlet weak var coverArtworkImageView: UIImageView!
	@IBOutlet weak var titleLabel: UILabel!
	@IBOutlet weak var artistLabel: UILabel!
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Do any additional setup after loading the view.
		setupTrackData()
		setupPlayer()
	}
	
	func setupPlayer() {
		do {
			
			try player.start(withClientId:SPTAuth.defaultInstance().clientID,
			                 audioController: bridgingAudioController,
			                 allowCaching: true)
			player.delegate = self
			player.playbackDelegate = self
			player.diskCache = SPTDiskCache.init(capacity: 1024 * 1024 * 64)
			player.login(withAccessToken: Spotify.user.accessToken.value)
		} catch {
			NSLog("Could not Start the Spotify audio streamer.")
		}
		
	}
	
	func setupTrackData() {
		if let unwrappedTrack = track {
			titleLabel.text = unwrappedTrack.name
			artistLabel.text = unwrappedTrack.artists[0] as? String
			URLSession.shared.dataTask(
				with: unwrappedTrack.album.largestCover.imageURL,
				completionHandler: {(data, response, error)->Void in
					if let imageData = data {
						let coverImage = UIImage(data: imageData)
						OperationQueue.main.addOperation(){
							self.coverArtLoadingIndicator.stopAnimating()
							self.coverArtworkImageView.image = coverImage
						}
					}
			}).resume()
		}
	}
	
	func audioStreamingDidLogin(_ audioStreaming: SPTAudioStreamingController!) {
		playPauseButton.isEnabled = true
		player.playSpotifyURI(track?.playableUri.absoluteString,
		                      startingWith: 0,
		                      startingWithPosition: 0,
		                      callback: nil)
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	@IBAction func playPause() {
	}
	
	/*
	// MARK: - Navigation
	
	// In a storyboard-based application, you will often want to do a little preparation before navigation
	override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
	// Get the new view controller using segue.destinationViewController.
	// Pass the selected object to the new view controller.
	}
	*/
	
}
