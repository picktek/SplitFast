//
//  ContentView.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import SwiftUI

struct ContentView: View {
    @State private var showImagePicker : Bool = false
    @State private var partDuration : Float64 =  Float64(UserDefaults.standard.double(forKey: "partDuration") ) 
    @State private var splitProggress = 0.0
    @State private var splitTotal = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            
            ScrollView(showsIndicators: false) {
                VStack {
                    if(splitTotal > splitProggress) {
                        ProgressView("Spliting…", value: splitProggress, total: splitTotal).padding()
                    } else {
                        Text("Video Part duration: \(partDuration, specifier: "%.2f")")
                            .foregroundColor(.blue)
                        HStack {
                            Button("-") {
                                partDuration -= 0.5
                            }.buttonStyle(.bordered)
                            Slider(    value: $partDuration,
                                       in: 10...90,
                                       step: 0.5,
                                       onEditingChanged:{_ in
                                UserDefaults.standard.set(Double(partDuration), forKey: "partDuration")
                                UserDefaults.standard.synchronize()
                                
                            })
                            Button("+") {
                                partDuration += 0.5
                            }.buttonStyle(.bordered)
                        }.padding()
                        Button("Choose Video") {
                            self.showImagePicker = true
                        }.buttonStyle(.bordered)
                    }
                }
                .padding()
                .frame(minHeight: geometry.size.height)
                .sheet(isPresented: self.$showImagePicker) {
                    VideoPicker(isShown: self.$showImagePicker, partDuration: self.$partDuration, parts: self.$splitProggress, totalParts:  self.$splitTotal)
                }
                Text(
                    (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-")
                    + " (" +
                    (Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-")
                    + ")"
                ).padding(-20)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


