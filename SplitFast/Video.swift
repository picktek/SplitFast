//
//  Video.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import Foundation
import AVKit
import Dispatch
import Photos
import AVFoundation

func generateThumbnail(path: URL) -> UIImage? {
    do {
        let asset = AVURLAsset(url: path, options: nil)
        let imgGenerator = AVAssetImageGenerator(asset: asset)
        imgGenerator.appliesPreferredTrackTransform = true
        let cgImage = try imgGenerator.copyCGImage(at: CMTimeMake(value: 0, timescale: 1), actualTime: nil)
        let thumbnail = UIImage(cgImage: cgImage)
        return thumbnail
    } catch let error {
        print("*** Error generating thumbnail: \(error.localizedDescription)")
        return nil
    }
}

func handleVideo(url: URL, partDuration: Float64 = 30.0, completion: @escaping  (Double, Double) -> Bool) async {
    print("handleVideo: ", url)
    
    let asset = AVAsset(url: url)
    let duration = try! await asset.load(.duration)
    let durationTime = CMTimeGetSeconds(duration)
    
    if (durationTime <= partDuration) {
        return;
    }
    
    var durationLeft = durationTime;
    var start = 0.0;
    
    var partTimes: [[CMTime]] = []
    
    while (durationLeft > 0) {
        partTimes.append([CMTime(seconds: start, preferredTimescale: duration.timescale),CMTime(seconds: start + min(partDuration, durationLeft), preferredTimescale: duration.timescale)]);
        durationLeft -= partDuration
        start += partDuration
    }
    var progress:Double = 0.01;
    let total: Double = Double(partTimes.count)
    
    var shouldStop = completion(progress, Double(partTimes.count))
    
    if(shouldStop) {
        return
    }
    
    var partURLS: [URL] = [];
    
    var failed = false;
    
    for time in partTimes {
        var prevP = 0.0;
        let partURL = await export(asset, startTime: time[0], endTime: time[1], proggress: {p in
            progress -= prevP
            progress += min(p, 0.9)
            prevP = min(p, 0.9)
            return completion(progress, total)
        })
        
        
        if (partURL != nil) {
            partURLS.append(partURL!);
        } else {
            failed = true
            break;
        }
        
        durationLeft -= partDuration
        start += partDuration
    }
    
    if(failed) {
        removeCacheDir()
        shouldStop = completion(-1,-1)
        return
    }
    
    for partURL in partURLS {
        do {
            try await PHPhotoLibrary.shared().performChanges({
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: partURL)
            })
        } catch {
          return
        }
        progress+=0.1
        shouldStop = completion(min(progress, total-0.1), total)
        if(shouldStop) {
            return
        }
    }
    
    shouldStop = completion(total - 0.1, total)
    removeCacheDir()
    
    shouldStop = completion(total,total)
}


func export(_ asset: AVAsset, startTime: CMTime, endTime: CMTime, proggress: @escaping (Double) -> Bool) async -> URL? {
    
    //Create trim range
    let timeRange = CMTimeRangeFromTimeToTime(start: startTime, end: endTime)
    
    print("Start \(CMTimeGetSeconds(timeRange.start))")
    print("end \(CMTimeGetSeconds(timeRange.end))")
    
    let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
    let path = cacheDir!.appendingPathComponent("split_part_\(UUID().uuidString).mov")
    
    let outputMovieURL = path
    
    do {
        try FileManager.default.removeItem(at: outputMovieURL)
    } catch {
        print("Could not remove file \(error.localizedDescription)")
    }
    
    //create exporter
    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough)
    
    //configure exporter
    exporter?.outputURL = outputMovieURL
    exporter?.outputFileType = .mov
    exporter?.timeRange = timeRange
    
    DispatchQueue.main.async {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true, block: { t in
            let stop = proggress(Double(exporter?.progress ?? 0))
            
            if(stop) {
                exporter?.cancelExport()
                t.invalidate()
                return
            }
            
            print(  Double(exporter?.progress ?? 0))
            if(Double(exporter?.progress ?? 0) > 0.99) {
                t.invalidate()
            }
            
            if(exporter?.status == .failed) {
                exporter?.cancelExport()
                t.invalidate()
            }
            
            
            
        })
    }
    
    
    await exporter?.export()
    
    //export!
    if let error = exporter?.error {
        print("AVAssetExportSessionERROR: \(error.localizedDescription)")
        return nil;
    } else {
        print("Video saved to \(outputMovieURL)")
        
        return outputMovieURL;
        
        
    }
    
    
}

func removeCacheDir() {
    let fileManager = FileManager.default
    let documentsUrl =  FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first! as NSURL
    let documentsPath = documentsUrl.path
    
    do {
        if let documentPath = documentsPath
        {
            let fileNames = try fileManager.contentsOfDirectory(atPath: "\(documentPath)")
            print("all files in cache: \(fileNames)")
            for fileName in fileNames {
                
                let filePathName:String = "\(documentPath)/\(fileName)"
                if(filePathName.contains("split_part_")) {
                    try fileManager.removeItem(atPath: filePathName)
                }
                
            }
            
        }
        
    } catch {
        print("Could not clear temp folder: \(error)")
    }
}
