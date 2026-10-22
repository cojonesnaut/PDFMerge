// Renders the Liquid Glass style app icon.
//   swift make_icon.swift <out-dir>
// Writes <out-dir>/icon.png (flattened 1024² icon for the .icns) and
// <out-dir>/AppIcon.icon (Icon Composer bundle: separate layers + icon.json, compiled by Xcode's actool).
import AppKit
import CoreImage

let S: CGFloat = 1024
let outDir = URL(fileURLWithPath: CommandLine.arguments[1])
let space = CGColorSpace(name: CGColorSpace.displayP3)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                            CGFloat(hex & 0xFF) / 255, a])!
}
func white(_ a: CGFloat) -> CGColor { CGColor(colorSpace: space, components: [1, 1, 1, a])! }

func newContext() -> CGContext {
    CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0, space: space,
              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}

func writePNG(_ image: CGImage, _ url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: Shapes

/// macOS icon shape: 824² rounded square (radius 185.4) centered in the 1024² canvas.
/// macOS checks icons against this outline and boxes anything that doesn't match inside a plate.
func squircle() -> CGPath {
    CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185.4, cornerHeight: 185.4, transform: nil)
}

func page(center: CGPoint, size: CGSize, angle: CGFloat, radius: CGFloat = 46) -> CGPath {
    var t = CGAffineTransform(translationX: center.x, y: center.y).rotated(by: angle * .pi / 180)
    let r = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
    return CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: &t)
}

// MARK: Layers (each drawn on its own transparent canvas)

let backPage = page(center: CGPoint(x: 432, y: 548), size: CGSize(width: 330, height: 430), angle: 9)
let frontPage = page(center: CGPoint(x: 548, y: 492), size: CGSize(width: 350, height: 450), angle: -5)
let badgeRect = CGRect(x: 588, y: 216, width: 236, height: 236)
let badge = CGPath(ellipseIn: badgeRect, transform: nil)

/// Text lines on the front page and the plus inside the badge, in page-local coordinates.
func frontGlyphs() -> CGPath {
    let path = CGMutablePath()
    let t = CGAffineTransform(translationX: 548, y: 492).rotated(by: -5 * .pi / 180)
    let widths: [CGFloat] = [210, 230, 190, 230, 130]
    for (i, w) in widths.enumerated() {
        let y = 130 - CGFloat(i) * 56
        path.addPath(CGPath(roundedRect: CGRect(x: -115, y: y, width: w, height: 24), cornerWidth: 12, cornerHeight: 12, transform: nil),
                     transform: t)
    }
    return path
}

func plusGlyph() -> CGPath {
    let path = CGMutablePath()
    let c = CGPoint(x: badgeRect.midX, y: badgeRect.midY)
    let l: CGFloat = 112, w: CGFloat = 30
    path.addRoundedRect(in: CGRect(x: c.x - w / 2, y: c.y - l / 2, width: w, height: l), cornerWidth: w / 2, cornerHeight: w / 2)
    path.addRoundedRect(in: CGRect(x: c.x - l / 2, y: c.y - w / 2, width: l, height: w), cornerWidth: w / 2, cornerHeight: w / 2)
    return path
}

// MARK: Background

func drawBackground(_ ctx: CGContext) {
    ctx.saveGState()
    ctx.addPath(squircle())
    ctx.clip()
    let base = CGGradient(colorsSpace: space, colors: [rgb(0xA4A7AF), rgb(0x63666E), rgb(0x34363C)] as CFArray,
                          locations: [0, 0.5, 1])!
    ctx.drawLinearGradient(base, start: CGPoint(x: 300, y: 924), end: CGPoint(x: 724, y: 100),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    // Soft light pool behind the pages so the glass has something to refract.
    let glow = CGGradient(colorsSpace: space, colors: [rgb(0xE6E7EA, 0.55), rgb(0xE6E7EA, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: 360, y: 700), startRadius: 0,
                           endCenter: CGPoint(x: 360, y: 700), endRadius: 420, options: [])
    let warm = CGGradient(colorsSpace: space, colors: [rgb(0xC9CCD2, 0.35), rgb(0xC9CCD2, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(warm, startCenter: CGPoint(x: 760, y: 300), startRadius: 0,
                           endCenter: CGPoint(x: 760, y: 300), endRadius: 360, options: [])
    ctx.restoreGState()
}

// MARK: Glass

let ci = CIContext(options: [.workingColorSpace: space])

func blurred(_ image: CGImage, radius: CGFloat) -> CGImage {
    let input = CIImage(cgImage: image).clampedToExtent()
    let out = input.applyingGaussianBlur(sigma: radius).cropped(to: CGRect(x: 0, y: 0, width: S, height: S))
    return ci.createCGImage(out, from: out.extent, format: .RGBA8, colorSpace: space)!
}

/// Frosted glass: blurred backdrop, milky fill, specular rim, soft shadow.
func drawGlass(_ ctx: CGContext, shape: CGPath, tint: CGFloat = 0.22, shadow: CGFloat = 0.32) {
    let backdrop = blurred(ctx.makeImage()!, radius: 22)
    let box = shape.boundingBoxOfPath

    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 40, color: rgb(0x16171A, shadow))
    ctx.addPath(shape)
    ctx.setFillColor(white(0.01))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.draw(backdrop, in: CGRect(x: 0, y: 0, width: S, height: S))
    // Milky body, brighter toward the top like light passing through.
    let body = CGGradient(colorsSpace: space, colors: [white(tint + 0.2), white(tint)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(body, start: CGPoint(x: box.midX, y: box.maxY), end: CGPoint(x: box.midX, y: box.minY), options: [])
    // Specular sheen across the upper-left
    let sheen = CGGradient(colorsSpace: space, colors: [white(0.35), white(0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(sheen, startCenter: CGPoint(x: box.minX + box.width * 0.2, y: box.maxY - box.height * 0.1),
                           startRadius: 0, endCenter: CGPoint(x: box.minX + box.width * 0.2, y: box.maxY - box.height * 0.1),
                           endRadius: max(box.width, box.height) * 0.7, options: [])
    ctx.restoreGState()

    // Rim: bright edge top-left fading to a faint edge bottom-right.
    ctx.saveGState()
    ctx.addPath(shape)
    ctx.clip()
    ctx.addPath(shape)
    ctx.setLineWidth(7)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    let rim = CGGradient(colorsSpace: space, colors: [white(0.95), white(0.25), white(0.6)] as CFArray, locations: [0, 0.6, 1])!
    ctx.drawLinearGradient(rim, start: CGPoint(x: box.minX, y: box.maxY), end: CGPoint(x: box.maxX, y: box.minY), options: [])
    ctx.restoreGState()
}

func fill(_ ctx: CGContext, _ path: CGPath, _ color: CGColor) {
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
}

// MARK: Flattened icon

let flat = newContext()
drawBackground(flat)
drawGlass(flat, shape: backPage, tint: 0.16, shadow: 0.22)
drawGlass(flat, shape: frontPage, tint: 0.26)
fill(flat, frontGlyphs(), white(0.92))
drawGlass(flat, shape: badge, tint: 0.3, shadow: 0.38)
fill(flat, plusGlyph(), white(1))
// Hairline edge on the icon body, as on system icons.
flat.saveGState()
flat.addPath(squircle())
flat.clip()
flat.addPath(squircle())
flat.setLineWidth(5)
flat.setStrokeColor(white(0.28))
flat.strokePath()
flat.restoreGState()

try! FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
writePNG(flat.makeImage()!, outDir.appendingPathComponent("icon.png"))

// MARK: Icon Composer bundle (the system renders the glass itself from these flat layers)

let bundle = outDir.appendingPathComponent("AppIcon.icon")
let assets = bundle.appendingPathComponent("Assets")
try? FileManager.default.removeItem(at: bundle)
try! FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

func layer(_ name: String, _ draw: (CGContext) -> Void) {
    let ctx = newContext()
    draw(ctx)
    writePNG(ctx.makeImage()!, assets.appendingPathComponent(name))
}
layer("back-page.png") { fill($0, backPage, white(1)) }
layer("front-page.png") { fill($0, frontPage, white(1)) }
// Neutral greys picked to match the brightness of the original indigo, so the Clear renderings
// (which macOS derives from layer brightness) don't change.
layer("lines.png") { fill($0, frontGlyphs(), rgb(0x696969)) }
layer("badge.png") { fill($0, badge, rgb(0x787878)) }
layer("plus.png") { fill($0, plusGlyph(), white(1)) }

let json = """
{
  "fill" : {
    "linear-gradient" : [
      "display-p3:0.64314,0.65490,0.68627,1.00000",
      "display-p3:0.20392,0.21176,0.23529,1.00000"
    ]
  },
  "groups" : [
    {
      "layers" : [
        { "image-name" : "plus.png", "name" : "plus", "glass" : false },
        { "image-name" : "badge.png", "name" : "badge", "glass" : true }
      ],
      "shadow" : { "kind" : "layer-color", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.3 }
    },
    {
      "layers" : [
        { "image-name" : "lines.png", "name" : "lines", "glass" : false },
        { "image-name" : "front-page.png", "name" : "front-page", "glass" : true }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : true, "value" : 0.4 }
    },
    {
      "layers" : [
        { "image-name" : "back-page.png", "name" : "back-page", "glass" : true, "opacity" : 0.7 }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.4 },
      "translucency" : { "enabled" : true, "value" : 0.6 }
    }
  ],
  "supported-platforms" : {
    "squares" : [ "macOS" ]
  }
}
"""
try! json.write(to: bundle.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
