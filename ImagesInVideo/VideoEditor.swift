//
//  ConvertingPicturesIntoVideos.swift
//  ImagesInVideo
//
//  Created by Даниил Мухсинятов on 02.03.2023.
//

import Foundation
import UIKit
import AVFoundation

class VideoEditor {
    
    private var widthVideo: Int = 0
    private var heightVideo: Int = 0
    
    private func createPixelBuffer(_ image: UIImage) -> CVPixelBuffer? {
        //create a variable to hold the pixelBuffer
        var pixelBuffer: CVPixelBuffer?
        let uikitImage = image
        guard let staticImage = CIImage(image: uikitImage) else {
            print("Error") 
            return nil
        }
        //set some standard attributes
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        //create the width and height of the buffer to match the image
        let width:Int = Int(staticImage.extent.size.width)
        widthVideo = width
        
        let height:Int = Int(staticImage.extent.size.height)
        heightVideo = height
        
        //create a buffer (notice it uses an in/out parameter for the pixelBuffer variable)
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &pixelBuffer)
        //    create a CIContext
        let context = CIContext()
        //use the context to render the image into the pixelBuffer
        context.render(staticImage, to: pixelBuffer!)
        return pixelBuffer
    }
    
    private func createVideo(_ pixelBuffer: CVPixelBuffer?, videoName: String, duration: Double) async -> URL? {

        //generate a file url to store the video. some_image.jpg becomes some_image.mov
        guard let imageNameRoot = videoName.split(separator: ".").first, let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("\(imageNameRoot).mov") else {
            print("Error")
            return nil
        }
        //delete any old file
        do {
            try FileManager.default.removeItem(at: outputMovieURL)
        } catch {
            print("Could not remove file \(error.localizedDescription)")
        }
        //create an assetwriter instance
        guard let assetwriter = try? AVAssetWriter(outputURL: outputMovieURL, fileType: .mov) else {
            abort()
        }
        //generate 1080p settings
        let assetWriterSettings = [AVVideoCodecKey: AVVideoCodecType.h264,
                                  AVVideoWidthKey : widthVideo,
                                  AVVideoHeightKey: heightVideo] as [String : Any]
        
        // to do: may come in handy //let settingsAssistant = AVOutputSettingsAssistant(preset: .preset3840x2160)?.videoSettings
        
        //create a single video input
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: assetWriterSettings)
        //create an adaptor for the pixel buffer
        let assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)
        //add the input to the asset writer
        assetwriter.add(assetWriterInput)
        //begin the session
        assetwriter.startWriting()
        assetwriter.startSession(atSourceTime: CMTime.zero)
        //determine how many frames we need to generate
        let framesPerSecond = 30
        //duration is the number of seconds for the final video
        let totalFrames = Int(duration * Double(framesPerSecond))
        var frameCount = 0
        while frameCount < totalFrames {
            if assetWriterInput.isReadyForMoreMediaData {
                let frameTime = CMTimeMake(value: Int64(frameCount), timescale: Int32(framesPerSecond))
                //append the contents of the pixelBuffer at the correct time
                assetWriterAdaptor.append(pixelBuffer!, withPresentationTime: frameTime)
                frameCount+=1
            }
        }
        //close everything
        assetWriterInput.markAsFinished()
        await assetwriter.finishWriting()
        print(outputMovieURL)
        return outputMovieURL
    }
    
    private func mergeVideos(urls: [URL], music: URL, finalVideoName: String) async -> URL? {
        
        guard let imageNameRoot = finalVideoName.split(separator: ".").first, let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("\(imageNameRoot).mov") else {
            print("Error")
            return nil
        }
        //delete any old file
        do {
            try FileManager.default.removeItem(at: outputMovieURL)
        } catch {
            print("Could not remove file \(error.localizedDescription)")
        }
        
        let movie = AVMutableComposition()
        let videoTrack = movie.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = movie.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        let beachMusec = AVURLAsset(url: music)
        
        for url in urls {
            let beachMovie = AVURLAsset(url: url)
            
            
            let beachVideoTrack = try! await beachMovie.loadTracks(withMediaType: .video).first!
            let beachRange = try! await CMTimeRangeMake(start: CMTime.zero, duration: beachMovie.load(.duration)) //3
            
            do {
                try videoTrack?.insertTimeRange(beachRange, of: beachVideoTrack, at: CMTime.zero) //4
            } catch {
                print(error)
            }
        }
        
        let beachAudioTrack = try! await beachMusec.loadTracks(withMediaType: .audio).first! //2
        
        do {
            try await audioTrack?.insertTimeRange(CMTimeRangeMake(start: CMTime.zero, duration: beachMusec.load(.duration)), of: beachAudioTrack, at: CMTime.zero)
        } catch {
            print(error)
        }
        let exporter = AVAssetExportSession(asset: movie,
                                            presetName: AVAssetExportPresetHighestQuality) //1
        
        
        //configure exporter
        exporter?.outputURL = outputMovieURL //2
        exporter?.outputFileType = .mov
        // export!
        await exporter?.export()
        
        print(outputMovieURL)
        return outputMovieURL
    }
    
    
    func createClip(images: [UIImage], music: URL) async -> URL {
        let musicDuratuon = try! await AVURLAsset(url: music).load(.duration).seconds
        let durationFragmentVideo = musicDuratuon / Double(images.count)
        var arrayFragmentVideo = [URL]()
        var nemeVideo = 0
        for image in images {
            nemeVideo += 1
            await arrayFragmentVideo.append(createVideo(createPixelBuffer(image),
                                                        videoName: "\(nemeVideo)",
                                                  duration: durationFragmentVideo)!)
        }
        
        return await mergeVideos(urls: arrayFragmentVideo, music: music, finalVideoName: "\(nemeVideo)mergeVideos")!
    }
}


