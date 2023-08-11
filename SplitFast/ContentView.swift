//
//  ContentView.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import SwiftUI
import BackgroundTasks

struct ContentView: View {
    @State private var showImagePicker : Bool = false
    @State private var partDuration : Double =  0.0
    @State private var splitProggress = 0.0
    @State private var splitTotal = 0.0
    @State private var inputFile:String? = nil
    @State private var backgroundTaskID:UIBackgroundTaskIdentifier? = nil
    @State private var shouldStop:Bool = false
    @State private var processing:Bool = false
        
    
    func getDuration() -> Double {
        if let userDefaults = UserDefaults(suiteName: "group.splitfast.storage") {
            return userDefaults.double(forKey: "partDuration") == 0 ? 30.0 : userDefaults.double(forKey: "partDuration")
            
        }
        
        return 0.0
    }
    
    func storeDuration(duration:Double) {
        if let userDefaults = UserDefaults(suiteName: "group.splitfast.storage") {
            userDefaults.set(duration, forKey: "partDuration")
            userDefaults.synchronize()
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            
            ScrollView(showsIndicators: false) {
                VStack {
                    if(splitTotal > splitProggress) {
                        Text("Will continue in background only for 25 second after it will be canceled").font(.system(size: 8)).padding().opacity(0.6).frame(maxWidth: .infinity, alignment: .leading)
                        HStack {
                            Text("Spliting…").frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(splitProggress, specifier: "%.2f") : \(splitTotal, specifier: "%.2f")")
                        }.padding()
                        ProgressView(value: splitProggress, total: splitTotal).padding()
                        Button("Stop", role: .destructive) {
                            self.shouldStop = true
                            UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
                            self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
                            self.splitProggress = 0.0
                            self.splitTotal = 0.0
                            Task {
                                removeCacheDir()
                            }
                        }.padding().buttonStyle(.bordered)
                    } else if(inputFile != nil) {
                        Image(uiImage: generateThumbnail(path: URL(string: inputFile!)!)!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width, height: geometry.size.height - 150, alignment: .topLeading)
                        Button("Start") {
                            print("Start")
                            self.shouldStop = false
                            
                            self.backgroundTaskID = UIApplication.shared.beginBackgroundTask (withName: "Split Large Video") {
                                print("BG Expired")
                                Task {
                                    let content = UNMutableNotificationContent()
                                    content.title = "Spliting Video Failed"
                                    content.body = "Spliting stoped try again"
                                    
                                    let uuidString = UUID().uuidString
                                    let request = UNNotificationRequest(identifier: uuidString,
                                                                        content: content, trigger: nil)
                                    
                                    
                                    // Schedule the request with the system.
                                    let notificationCenter = UNUserNotificationCenter.current()
                                    try await notificationCenter.add(request)
                                    
                                    UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
                                    self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
                                }
                            }
                            Task {
                                let targetURL = URL(string: inputFile!);
                                self.inputFile = nil
                                self.processing = true
                                await handleVideo(url: targetURL!, partDuration: self.partDuration, completion: {
                                    if(shouldStop) {
                                        return shouldStop
                                    } else {
                                        self.splitProggress = $0
                                        self.splitTotal = $1
                                    }
                                    
                                    return shouldStop
                                })
                                self.processing = false
                                print("Completed Spliting")
                                UIApplication.shared.endBackgroundTask(self.backgroundTaskID!)
                                self.backgroundTaskID = UIBackgroundTaskIdentifier.invalid
                                
                                DispatchQueue.main.async {
                                    if (UIApplication.shared.applicationState != .active) {
                                        Task {
                                            let content = UNMutableNotificationContent()
                                            content.title = "Spliting Video Completed"
                                            content.body = "Creasted \(self.splitTotal) parts"
                                            
                                            let uuidString = UUID().uuidString
                                            let request = UNNotificationRequest(identifier: uuidString,
                                                                                content: content, trigger: nil)
                                            
                                            
                                            // Schedule the request with the system.
                                            let notificationCenter = UNUserNotificationCenter.current()
                                            try await notificationCenter.add(request)
                                        }
                                    }
                                }
                            }
                            
                            
                        }.buttonStyle(.bordered).padding()
                        Button("cancel") {
                            self.shouldStop = true
                            self.inputFile = nil
                            Task {
                                removeCacheDir()
                            }
                        }.padding()
                    } else {
                        Text("Video Part duration: \(partDuration, specifier: "%.2f") Seconds")
                            .foregroundColor(.blue)
                        HStack {
                            Button("-") {
                                partDuration -= 0.5
                                storeDuration(duration: self.partDuration)
                            }.buttonStyle(.bordered)
                            Slider(    value: $partDuration,
                                       in: 10...180,
                                       step: 0.5,
                                       onEditingChanged:{_ in
                                storeDuration(duration: self.partDuration)
                                                                
                            })
                            Button("+") {
                                partDuration += 0.5
                                storeDuration(duration: self.partDuration)
                            }.buttonStyle(.bordered)
                        }.padding()
                        Button("Choose Video") {
                            self.showImagePicker = true
                        }.buttonStyle(.bordered).disabled(self.processing)
                    }
                }
                .padding()
                .frame(minHeight: geometry.size.height)
                .sheet(isPresented: self.$showImagePicker) {
                    VideoPicker(isShown: self.$showImagePicker, inputFile: self.$inputFile)
                }
                Text(
                    (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    + " (" +
                    (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                    + ")"
                ).frame(maxWidth: .infinity, alignment: .trailing)
                    .padding([.top], -50)
                    .padding([.trailing], 40)
            }
        }.onAppear(perform: {
            self.partDuration = getDuration()
        })
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
        
    }
}


