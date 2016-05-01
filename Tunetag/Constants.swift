//
//  Constants.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 4/10/16.
//  Copyright © 2016 Sean Fitzgerald. All rights reserved.
//

import Foundation

let SPOTIFY_USER_AUTH_TOKEN = "spotify user authentication token"
let SPOTIFY_CLIENT_ID = "6a986196cd80437fbf51807fb882c35a"
let SPOTIFY_AUTH_REDIRECT_URL = "tunetag://auth"
let SPOTIFY_AUTH_SCOPES =
    "playlist-read-private " + // Read access to user's private playlists.	"Access your private playlists"
        "playlist-read-collaborative " + // Include collaborative playlists when requesting a user's playlists.	"Access your collaborative playlists"
        "playlist-modify-private " + // Write access to a user's private playlists.	"Manage your private playlists"
        "playlist-modify-public " + // Write access to a user's public playlists.	"Manage your public playlists"
        "streaming " + // Control playback of a Spotify track.	"Play music and control playback on your other devices"
        "user-library-read " + // Read access to a user's "Your Music" library.	"Access your saved tracks and albums"
        "user-library-modify " + // Write/delete access to a user's "Your Music" library.	"Manage your saved tracks and albums"
        "user-read-email " + // Read access to user’s email address.	"Get your real email address"
        "user-top-read" // Read access to a user's top artists and tracks	"Read your top artists and tracks"
let SPOTIFY_SCOPE_AUTH_STATE = "SCOPE AUTHORIZATION"
let SPOTIFY_ACCESS_TOKEN = "spotify access token key"
let SPOTIFY_REFRESH_TOKEN = "spotify refresh token key"
let SPOTIFY_WEB_API_ACCESS_GROUP = "PTAUHZ2E6Z.SpotifyWebAPI.com.seantfitzgerald.Tunetag"

let AWS_LAMBDA_GET_TOKENS_FUNCTION_NAME = "SpotifyProxyGetTokens"
let AWS_LAMBDA_REFRESH_TOKENS_FUNCTION_NAME = "SpotifyProxyTokenRefresh"