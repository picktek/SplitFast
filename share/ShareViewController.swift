//
//  ShareViewController.swift
//  share
//
//  Created by l on 11.08.23.
//

import UIKit
import Social
import Photos
import UniformTypeIdentifiers

class ShareViewController: UIViewController {

     func isContentValid() -> Bool {
        // Do validation of contentText and/or NSExtensionContext attachments here
        print("isvalid")
        return true
    }


     func configurationItems() -> [Any]! {
        print("conf items")
        // To add configuration options via table cells at the bottom of the sheet, return an array of SLComposeSheetConfigurationItem here.
        return []
    }
    
    func getDuration() -> Double {
        if let userDefaults = UserDefaults(suiteName: "group.splitfast.storage") {
            return userDefaults.double(forKey: "partDuration") == 0 ? 30.0 : userDefaults.double(forKey: "partDuration")
            
        }
        
        return 30.0
    }
    
    
    override func viewDidLoad() {
        if let content = extensionContext!.inputItems[0] as? NSExtensionItem {
            if let contents = content.attachments {
                for (_, attachment) in (contents).enumerated() {
                    if attachment.hasItemConformingToTypeIdentifier(UTType.movie.description) {
                        
                        attachment.loadItem(forTypeIdentifier: UTType.movie.description, options: nil) { [weak self] data, error in
                            let item = data as! URL
                            
                            Task {
                                await handleVideo(url: item, partDuration: self!.getDuration(), completion: {_,_ in
                                    
                                    return false
                                })
                                self?.extensionContext!.completeRequest(returningItems: [], completionHandler: nil)
                            }
                        }
                    }
                }
            }
        }
    }
}
