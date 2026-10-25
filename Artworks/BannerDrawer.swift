//
//  BannerDrawer.swift
//  View
//
//  Created by 秋星桥 on 2024/3/6.
//

// swiftc -parse-as-library BannerDrawer.swift
// ./BannerDrawer

import QuickLook
import SwiftUI

@main
struct DemoApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}

struct ContentView: View {
    var body: some View {
        PreviewExporter()
            .scaleEffect(.init(width: 0.5, height: 0.5))
            .frame(width: 1920 / 2, height: 1080 / 2, alignment: .center)
    }
}

struct PreviewBackgroundView: View {
    var body: some View {
        ZStack {
            VStack {
                ForEach(0 ..< 32, id: \.self) { shift in
                    line(shift: shift)
                }
            }
            .fixedSize()
        }
    }

    func line(shift: Int) -> some View {
        HStack {
            ForEach(0 ... 4, id: \.self) { _ in
                ImageListView(shift: shift * 4)
            }
        }
    }
}

struct ImageListView: View {
    let imageList = [
        "circle",
        "checkmark.circle",
        "record.circle",
        "timelapse",
        "paintpalette",
        "swatchpalette",
        "lasso",
        "lasso.badge.sparkles",
        "sun.max",
        "moon",
        "wind",
        "cloud.rain",
    ]

    let shift: Int

    var body: some View {
        ForEach(0 ... 10, id: \.self) { value in
            Image(systemName: image(forIndex: value + shift))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .font(.system(size: 128))
                .padding(32)
                .frame(width: 128, height: 128, alignment: .center)
        }
    }

    func image(forIndex: Int) -> String {
        imageList[forIndex % imageList.count]
    }
}

struct PreviewBannerView: View {
    var body: some View {
        ZStack {
            Image(systemName: "hand.tap.fill")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 620, height: 620, alignment: .center)
                .font(.system(size: 620, weight: .bold, design: .rounded))
                .opacity(0.88)
                .padding(72)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(50)
        .background(
            PreviewBackgroundView()
                .foregroundStyle(.white)
                .opacity(0.05)
        )
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    .init(red: 244 / 255, green: 67 / 255, blue: 105 / 255),
                    .init(red: 62 / 255, green: 59 / 255, blue: 146 / 255),
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .rotationEffect(.degrees(15))
            .ignoresSafeArea()
            .padding(-500)
        )
        .frame(width: 1920, height: 1080, alignment: .center)
        .clipped()
    }
}

struct PreviewExporter: View {
    var body: some View {
        VStack {
            PreviewBannerView()
                .onTapGesture {
                    let renderer = ImageRenderer(content: PreviewBannerView())
                    let data = renderer.nsImage!.tiffRepresentation!
                    let url = URL(fileURLWithPath: NSTemporaryDirectory())
                        .appendingPathComponent("Banner")
                        .appendingPathExtension("tiff")
                    try! data.write(to: url)
                    NSWorkspace.shared.open(url)
                }
        }
    }
}
