// swift-tools-version:5.9
//
// Generate three 1024x1024 PNG variants of the WhistleCounter app icon:
//   AppIcon.png         — light/any, opaque terracotta background
//   AppIcon-Dark.png    — transparent background, cooker + arcs only
//   AppIcon-Tinted.png  — monochrome grayscale with transparency
//
// Run from repo root:
//     swift Tools/GenerateAppIcon.swift
//
// Output:
//     WhistleCounter/Assets.xcassets/AppIcon.appiconset/*.png
//
// The design is intentionally flat — iOS 26 adds its own specular
// highlight at render time, so the PNG should not contain gloss,
// drop shadows, or baked-in corner masks.

import SwiftUI
import AppKit

// MARK: - Palette

private enum Palette {
    static let backgroundTop    = Color(red: 0.91, green: 0.47, blue: 0.29) // #E8794A
    static let backgroundBottom = Color(red: 0.72, green: 0.29, blue: 0.15) // #B84B27
    static let cooker           = Color(red: 0.96, green: 0.90, blue: 0.83) // #F5E6D3
    static let accent           = Color(red: 0.23, green: 0.12, blue: 0.08) // #3A1F15
    static let darkCooker       = Color(red: 0.88, green: 0.82, blue: 0.75)
    static let tintedFill       = Color.white                                // iOS applies user tint
}

// MARK: - Icon shapes

/// A stylized pressure cooker body drawn relative to a 1x1 canvas,
/// centered horizontally with a slight downward bias so the whistle
/// arcs have room to breathe at the top.
private struct CookerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height
        let bodyWidth = width * 0.58
        let bodyHeight = height * 0.40
        let bodyX = (width - bodyWidth) / 2
        let bodyY = height * 0.48
        let cornerRadius = bodyHeight * 0.18

        // Main body — rounded rectangle.
        path.addRoundedRect(
            in: CGRect(x: bodyX, y: bodyY,
                       width: bodyWidth, height: bodyHeight),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // Lid — slightly wider than the body, on top.
        let lidWidth = bodyWidth * 1.08
        let lidHeight = height * 0.055
        let lidX = (width - lidWidth) / 2
        let lidY = bodyY - lidHeight * 0.5
        path.addRoundedRect(
            in: CGRect(x: lidX, y: lidY,
                       width: lidWidth, height: lidHeight),
            cornerSize: CGSize(width: lidHeight / 2, height: lidHeight / 2)
        )

        // Left and right handles.
        let handleWidth = width * 0.07
        let handleHeight = height * 0.035
        let handleY = bodyY + bodyHeight * 0.35
        path.addRoundedRect(
            in: CGRect(x: bodyX - handleWidth * 0.85,
                       y: handleY,
                       width: handleWidth,
                       height: handleHeight),
            cornerSize: CGSize(width: handleHeight / 2, height: handleHeight / 2)
        )
        path.addRoundedRect(
            in: CGRect(x: bodyX + bodyWidth - handleWidth * 0.15,
                       y: handleY,
                       width: handleWidth,
                       height: handleHeight),
            cornerSize: CGSize(width: handleHeight / 2, height: handleHeight / 2)
        )

        return path
    }
}

/// The whistle stem + cap that sits on top of the cooker lid.
private struct WhistleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        let width = rect.width
        let height = rect.height

        // Stem.
        let stemWidth = width * 0.05
        let stemHeight = height * 0.09
        let stemX = (width - stemWidth) / 2
        let stemY = height * 0.39
        path.addRoundedRect(
            in: CGRect(x: stemX, y: stemY,
                       width: stemWidth, height: stemHeight),
            cornerSize: CGSize(width: stemWidth / 2, height: stemWidth / 2)
        )

        // Cap — wider disc on top of the stem.
        let capWidth = width * 0.11
        let capHeight = height * 0.04
        let capX = (width - capWidth) / 2
        let capY = stemY - capHeight * 0.55
        path.addRoundedRect(
            in: CGRect(x: capX, y: capY,
                       width: capWidth, height: capHeight),
            cornerSize: CGSize(width: capHeight / 2, height: capHeight / 2)
        )

        return path
    }
}

/// One steam/sound arc. Two of these are drawn, offset vertically.
private struct SteamArc: Shape {
    var yOffsetFraction: CGFloat
    var widthFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let arcWidth = rect.width * widthFraction
        let arcHeight = rect.height * 0.10
        let centerX = rect.midX
        let centerY = rect.height * yOffsetFraction

        path.addArc(
            center: CGPoint(x: centerX, y: centerY),
            radius: arcWidth / 2,
            startAngle: .degrees(200),
            endAngle: .degrees(340),
            clockwise: false
        )
        _ = arcHeight
        return path
    }
}

// MARK: - Icon composition

/// Composes the icon. Three variants controlled by `Variant`.
private struct IconView: View {
    enum Variant {
        case any, dark, tinted
    }

    let variant: Variant

    var body: some View {
        ZStack {
            backgroundLayer
            VStack(spacing: 0) {
                Spacer()
                steamLayer
                Spacer().frame(height: 10)
                cookerLayer
                Spacer()
            }
        }
        .frame(width: 1024, height: 1024)
    }

    @ViewBuilder
    private var backgroundLayer: some View {
        switch variant {
        case .any:
            LinearGradient(
                colors: [Palette.backgroundTop, Palette.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )
        case .dark, .tinted:
            Color.clear
        }
    }

    private var cookerLayer: some View {
        ZStack {
            CookerShape()
                .fill(cookerFill)
            WhistleShape()
                .fill(accentFill)
        }
        .frame(width: 1024, height: 1024)
    }

    private var steamLayer: some View {
        ZStack {
            SteamArc(yOffsetFraction: 0.28, widthFraction: 0.24)
                .stroke(accentFill,
                        style: StrokeStyle(lineWidth: 28, lineCap: .round))
            SteamArc(yOffsetFraction: 0.19, widthFraction: 0.34)
                .stroke(accentFill,
                        style: StrokeStyle(lineWidth: 28, lineCap: .round))
        }
        .frame(width: 1024, height: 1024)
    }

    private var cookerFill: Color {
        switch variant {
        case .any:    Palette.cooker
        case .dark:   Palette.darkCooker
        case .tinted: Palette.tintedFill
        }
    }

    private var accentFill: Color {
        switch variant {
        case .any:    Palette.accent
        case .dark:   Palette.cooker
        case .tinted: Palette.tintedFill
        }
    }
}

// MARK: - Rendering

@MainActor
private func renderPNG(_ view: some View, to url: URL, opaque: Bool) throws {
    let renderer = ImageRenderer(content: view)
    renderer.proposedSize = ProposedViewSize(width: 1024, height: 1024)
    renderer.scale = 1.0
    renderer.isOpaque = opaque

    guard let nsImage = renderer.nsImage else {
        throw NSError(domain: "GenerateAppIcon", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Render failed"])
    }

    guard let tiff = nsImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "GenerateAppIcon", code: 2,
                      userInfo: [NSLocalizedDescriptionKey: "PNG encode failed"])
    }

    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try png.write(to: url)
    print("Wrote \(url.path)")
}

// MARK: - Entry point

@MainActor
func main() throws {
    let outputDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent("WhistleCounter/Assets.xcassets/AppIcon.appiconset")

    try renderPNG(
        IconView(variant: .any),
        to: outputDirectory.appendingPathComponent("AppIcon.png"),
        opaque: true
    )
    try renderPNG(
        IconView(variant: .dark),
        to: outputDirectory.appendingPathComponent("AppIcon-Dark.png"),
        opaque: false
    )
    try renderPNG(
        IconView(variant: .tinted),
        to: outputDirectory.appendingPathComponent("AppIcon-Tinted.png"),
        opaque: false
    )
}

try await MainActor.run { try main() }
