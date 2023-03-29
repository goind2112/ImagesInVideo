//
//  ConvertingPicturesIntoVideos.swift
//  ImagesInVideo
//
//  Created by Даниил Мухсинятов on 02.03.2023.
//

import Foundation
import UIKit
import AVFoundation
import RxSwift

class VideoEditor {
    
    private var widthVideo: Int = 0
    private var heightVideo: Int = 0
    
    private func createPixelBuffer(_ image: UIImage) -> CVPixelBuffer? {
        
        var pixelBuffer: CVPixelBuffer?
        let uikitImage = image
        guard let staticImage = CIImage(image: uikitImage) else {
            print("Error") 
            return nil
        }
        
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
             kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        let width:Int = Int(staticImage.extent.size.width)
        widthVideo = width
        
        let height:Int = Int(staticImage.extent.size.height)
        heightVideo = height
        
        CVPixelBufferCreate(kCFAllocatorDefault,
                            width,
                            height,
                            kCVPixelFormatType_32BGRA,
                            attrs,
                            &pixelBuffer)
       
        let context = CIContext()
        
        context.render(staticImage, to: pixelBuffer!)
        return pixelBuffer
    }
    
    private func createVideo(_ pixelBuffer: CVPixelBuffer?, videoName: String, duration: Double) async -> URL? {

        guard let imageNameRoot = videoName.split(separator: ".").first, let outputMovieURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent("\(imageNameRoot).mov") else {
            print("Error")
            return nil
        }
        
        do {
            try FileManager.default.removeItem(at: outputMovieURL)
        } catch {
            print("Could not remove file \(error.localizedDescription)")
        }
        
        guard let assetwriter = try? AVAssetWriter(outputURL: outputMovieURL, fileType: .mov) else {
            abort()
        }
        
        let assetWriterSettings = [AVVideoCodecKey: AVVideoCodecType.h264,
                                  AVVideoWidthKey : widthVideo,
                                  AVVideoHeightKey: heightVideo] as [String : Any]
        
        let assetWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: assetWriterSettings)
        
        let assetWriterAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: assetWriterInput, sourcePixelBufferAttributes: nil)
        
        assetwriter.add(assetWriterInput)
        
        assetwriter.startWriting()
        assetwriter.startSession(atSourceTime: CMTime.zero)
        
        let framesPerSecond = 30
       
        let totalFrames = Int(duration * Double(framesPerSecond))
        var frameCount = 0
        while frameCount < totalFrames {
            if assetWriterInput.isReadyForMoreMediaData {
                let frameTime = CMTimeMake(value: Int64(frameCount), timescale: Int32(framesPerSecond))
                
                assetWriterAdaptor.append(pixelBuffer!, withPresentationTime: frameTime)
                frameCount+=1
            }
        }
        
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
        
        
        
        exporter?.outputURL = outputMovieURL //2
        exporter?.outputFileType = .mov
        
        await exporter?.export()
        
        print(outputMovieURL)
        return outputMovieURL
    }
    
    
    func createClip(images: [UIImage], music: URL) async -> URL? {
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


