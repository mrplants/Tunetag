//
//  BridgingAudioController.swift
//  Tunetag
//
//  Created by Sean Fitzgerald on 5/30/17.
//  Copyright © 2017 Sean Fitzgerald. All rights reserved.
//

import Foundation

class BridgingAudioController: SPTCoreAudioController {
	
	var ioUnit:AudioUnit?
	
	override func connectOutputBus(_ sourceOutputBusNumber: UInt32,
	                               ofNode sourceNode: AUNode,
	                               toInputBus destinationInputBusNumber: UInt32,
	                               ofNode destinationNode: AUNode,
	                               in graph: AUGraph!) throws {
		// Get the Audio Unit from the node so we can set bands directly later
		AUGraphNodeInfo(graph, destinationNode, nil, &ioUnit)
		
		AudioUnitAddRenderNotify(ioUnit!,renderCallback, Unmanaged.passUnretained(self).toOpaque())
		
		try super.connectOutputBus(sourceOutputBusNumber,
		                       ofNode: sourceNode,
		                       toInputBus: destinationInputBusNumber,
		                       ofNode: destinationNode,
		                       in: graph)
	}
}

func renderCallback(inRefCon:UnsafeMutableRawPointer,
                    ioActionFlags:UnsafeMutablePointer<AudioUnitRenderActionFlags>,
                    inTimeStamp:UnsafePointer<AudioTimeStamp>,
                    inBusNumber:UInt32,
                    inNumberFrames:UInt32,
                    ioData:UnsafeMutablePointer<AudioBufferList>?) -> Int32 {
	if let data = ioData {
		let bufferPointer = UnsafeMutablePointer<AudioBuffer>(&data.pointee.mBuffers)
		NSLog("Audio frame buffer(L): \(bufferPointer[0].mData?.load(as: Float32.self) ?? 0)")
		NSLog("Audio frame buffer(R): \(bufferPointer[1].mData?.load(as: Float32.self) ?? 0)")
	}
	return 0
}
