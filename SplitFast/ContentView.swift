//
//  ContentView.swift
//  SplitFast
//
//  Created by l on 09.08.23.
//

import SwiftUI

struct ContentView: View {
    @State private var showImagePicker : Bool = false
    @AppStorage("partDuration") private var partDuration : Float64 = 30.0
    @State private var splitProggress = 0.0
    @State private var splitTotal = 0.0
    
    var body: some View {
        VStack {
            
            if(splitTotal > splitProggress) {
                ProgressView("Spliting…", value: splitProggress, total: splitTotal).padding()
            } else {
                Text("Video Part duration: \(partDuration, specifier: "%.2f")")
                    .foregroundColor(.blue)
                Slider(    value: $partDuration,
                           in: 10...90,
                           step: 0.5).padding()
                Button("Choose Video") {
                    self.showImagePicker = true
                }.buttonStyle(.bordered)
            }
            
        }
        .padding()
        .sheet(isPresented: self.$showImagePicker) {
            VideoPicker(isShown: self.$showImagePicker, partDuration: self.$partDuration, parts: $splitProggress, totalParts:  $splitTotal)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}


