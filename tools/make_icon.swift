// Renders the app icon. Usage: swiftc -O tools/make_icon.swift -o /tmp/make_icon && /tmp/make_icon ios.png mac.png
import AppKit

let S: CGFloat = 1024

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255,
            blue: CGFloat(hex & 255) / 255, alpha: a)
}

/// Draws a side-view rabbit mid-sprint (facing right) with speed lines.
func drawRabbit(_ c: CGContext, rabbit: Bool = true, streaks: Bool = true, streakColor: CGColor = rgb(0xB5D6FF)) {
    let white = rgb(0xFFFFFF), shade = rgb(0xC9DEFF), ink = rgb(0x12234D), pink = rgb(0xFFB3C6)

    func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat, _ angle: CGFloat, _ color: CGColor) {
        c.saveGState()
        c.translateBy(x: cx, y: cy); c.rotate(by: angle)
        c.setFillColor(color)
        c.fillEllipse(in: CGRect(x: -w / 2, y: -h / 2, width: w, height: h))
        c.restoreGState()
    }
    /// Tapered limb: round end caps of different radii joined by straight tangents.
    func taper(_ x1: CGFloat, _ y1: CGFloat, _ r1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ r2: CGFloat, _ color: CGColor) {
        let dx = x2 - x1, dy = y2 - y1, d = hypot(dx, dy)
        let nx = -dy / d, ny = dx / d
        c.setFillColor(color)
        c.fillEllipse(in: CGRect(x: x1 - r1, y: y1 - r1, width: 2 * r1, height: 2 * r1))
        c.fillEllipse(in: CGRect(x: x2 - r2, y: y2 - r2, width: 2 * r2, height: 2 * r2))
        c.move(to: CGPoint(x: x1 + nx * r1, y: y1 + ny * r1))
        c.addLine(to: CGPoint(x: x2 + nx * r2, y: y2 + ny * r2))
        c.addLine(to: CGPoint(x: x2 - nx * r2, y: y2 - ny * r2))
        c.addLine(to: CGPoint(x: x1 - nx * r1, y: y1 - ny * r1))
        c.closePath(); c.fillPath()
    }

    c.saveGState()
    // Center the artwork's bounding box on the canvas.
    c.translateBy(x: 512, y: 512); c.scaleBy(x: 0.98, y: 0.98); c.translateBy(x: -500, y: -548)

    // Speed streaks: tapered, thinning toward the tail end.
    if streaks {
        taper(120, 655, 5, 290, 655, 17, streakColor)
        taper(60, 540, 5, 160, 540, 17, streakColor)
        taper(60, 425, 5, 175, 425, 17, streakColor)
    }
    guard rabbit else { c.restoreGState(); return }

    // Far side (tinted for depth): ear, hind leg, front leg.
    ellipse(560, 700, 330, 74, -0.45, shade)
    taper(330, 440, 52, 160, 345, 15, shade)
    taper(660, 470, 30, 830, 410, 14, shade)

    // Tail, body and chest.
    ellipse(262, 545, 92, 92, 0, white)
    ellipse(490, 500, 440, 210, 0.07, white)
    ellipse(640, 490, 190, 170, 0.3, white)
    // Near hind leg: thigh, then a long tapered foot stretched back.
    ellipse(345, 470, 230, 210, 0.45, white)
    taper(335, 430, 58, 150, 335, 20, white)
    // Near front leg reaching forward.
    taper(655, 465, 34, 845, 395, 16, white)

    // Head with a tapered muzzle.
    ellipse(715, 565, 200, 150, 0.15, white)
    ellipse(800, 548, 120, 84, -0.28, white)
    // Near ear with pink inner.
    ellipse(542, 703, 350, 82, -0.45, white)
    ellipse(542, 703, 262, 36, -0.45, pink)

    // Face.
    ellipse(745, 585, 34, 34, 0, ink)
    ellipse(753, 593, 11, 11, 0, white)
    ellipse(851, 548, 40, 32, 0, rgb(0xFF8A5B))
    c.restoreGState()
}

func gradient(_ c: CGContext, in rect: CGRect) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors:
        [rgb(0x5BC0FF), rgb(0x2457F5)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: rect.minX, y: rect.maxY), end: CGPoint(x: rect.maxX, y: rect.minY), options: [])
}

func render(mac: Bool, to path: String) {
    let info = mac ? CGImageAlphaInfo.premultipliedLast.rawValue : CGImageAlphaInfo.noneSkipLast.rawValue
    let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)!
    if mac {
        // Big Sur style: 824pt rounded square on a transparent 1024 canvas, with a soft shadow.
        let r = CGRect(x: 100, y: 100, width: 824, height: 824)
        let shape = CGPath(roundedRect: r, cornerWidth: 185, cornerHeight: 185, transform: nil)
        c.saveGState()
        c.setShadow(offset: CGSize(width: 0, height: -12), blur: 24, color: rgb(0x000000, 0.3))
        c.addPath(shape); c.setFillColor(rgb(0x2457F5)); c.fillPath()
        c.restoreGState()
        c.saveGState()
        c.addPath(shape); c.clip()
        gradient(c, in: r)
        c.translateBy(x: 512, y: 512); c.scaleBy(x: 824 / 1024, y: 824 / 1024); c.translateBy(x: -512, y: -512)
        drawRabbit(c)
        c.restoreGState()
    } else {
        // iOS: full-bleed square, no transparency; the system applies the rounded mask.
        gradient(c, in: CGRect(x: 0, y: 0, width: S, height: S))
        drawRabbit(c)
    }
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

/// Transparent 1024 layers for Icon Composer (drag into a new .icon document).
func renderLayer(to path: String, _ draw: (CGContext) -> Void, opaque: Bool = false) {
    let info = opaque ? CGImageAlphaInfo.noneSkipLast.rawValue : CGImageAlphaInfo.premultipliedLast.rawValue
    let c = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: info)!
    draw(c)
    let rep = NSBitmapImageRep(cgImage: c.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}

render(mac: false, to: CommandLine.arguments[1])
render(mac: true, to: CommandLine.arguments[2])
if CommandLine.arguments.count > 3 {
    let dir = CommandLine.arguments[3]
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    renderLayer(to: dir + "/background.png", { gradient($0, in: CGRect(x: 0, y: 0, width: S, height: S)) }, opaque: true)
    renderLayer(to: dir + "/rabbit.png", { drawRabbit($0, streaks: false) })
    renderLayer(to: dir + "/speed_lines.png", { drawRabbit($0, rabbit: false, streakColor: rgb(0xFFFFFF)) })
}
