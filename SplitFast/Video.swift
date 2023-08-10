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

func handleVideo(url: URL, partDuration: Float64 = 30.0, completion: ((Double, Double) -> Void)? = nil) async {
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
    
    completion?(progress, Double(partTimes.count))
    
    var partURLS: [URL] = [];

    for time in partTimes {
        var prevP = 0.0;
        let partURL = await export(asset, startTime: time[0], endTime: time[1], proggress: {p in
            progress -= prevP
            progress += min(p, 0.9)
            prevP = min(p, 0.9)
            completion?(progress, total)
        })
        
        
        if (partURL != nil) {
            partURLS.append(partURL!);
        }

        durationLeft -= partDuration
        start += partDuration
    }
    

    for partURL in partURLS {
        try! await PHPhotoLibrary.shared().performChanges({
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: partURL)
        })
        progress+=0.1
        completion?(min(progress, total-0.1), total)
    }
    
    completion?(total - 0.1, total)
    removeCacheDir()
    
    completion?(total,total)
}

func export(_ asset: AVAsset, startTime: CMTime, endTime: CMTime, proggress: @escaping (Double) -> Void) async -> URL? {

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
    let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)

    //configure exporter
    exporter?.outputURL = outputMovieURL
    exporter?.outputFileType = .mov
    exporter?.timeRange = timeRange

    
    DispatchQueue.main.async {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true, block: { t in
            print(outputMovieURL, Double(exporter?.progress ?? 0))
            proggress(Double(exporter?.progress ?? 0))
            
            if(Double(exporter?.progress ?? 0) > 0.99) {
                t.invalidate()
            }
        })
    }
            
    
    await exporter?.export()
    
    //export!
    if let error = exporter?.error {
        print("failed \(error.localizedDescription)")
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
                        if(filePathName.hasPrefix("split_part_")) {
                            try fileManager.removeItem(atPath: filePathName)
                        }
                        
                    }

                }

            } catch {
                print("Could not clear temp folder: \(error)")
            }
}
