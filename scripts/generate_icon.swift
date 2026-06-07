import Cocoa

func drawMasterIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    let context = NSGraphicsContext.current?.cgContext
    
    // --- 1. Background Gradient (Sleek dark gradient with deep blue/purple glow) ---
    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let bgPath = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.05, dy: size * 0.05), xRadius: size * 0.22, yRadius: size * 0.22)
    bgPath.addClip()
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bgColors = [
        NSColor(red: 0.08, green: 0.05, blue: 0.20, alpha: 1.0).cgColor,
        NSColor(red: 0.18, green: 0.08, blue: 0.35, alpha: 1.0).cgColor,
        NSColor(red: 0.05, green: 0.12, blue: 0.25, alpha: 1.0).cgColor
    ] as CFArray
    let bgLocations: [CGFloat] = [0.0, 0.5, 1.0]
    
    if let bgGradient = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: bgLocations) {
        context?.drawLinearGradient(bgGradient, start: CGPoint(x: 0, y: size), end: CGPoint(x: size, y: 0), options: [])
    }
    
    // --- 2. Dynamic glowing lines inside background ---
    context?.saveGState()
    let glowPath = NSBezierPath()
    glowPath.move(to: NSPoint(x: size * 0.2, y: size * 0.8))
    glowPath.curve(to: NSPoint(x: size * 0.8, y: size * 0.2), controlPoint1: NSPoint(x: size * 0.4, y: size * 0.9), controlPoint2: NSPoint(x: size * 0.6, y: size * 0.1))
    
    context?.setStrokeColor(NSColor(red: 0.0, green: 0.8, blue: 1.0, alpha: 0.3).cgColor)
    context?.setLineWidth(size * 0.08)
    context?.setLineCap(.round)
    context?.setBlendMode(.screen)
    glowPath.stroke()
    context?.restoreGState()
    
    // --- 3. LiquidGlass Overlay Disc (Frosted Glass Effect) ---
    context?.saveGState()
    let glassRect = bounds.insetBy(dx: size * 0.18, dy: size * 0.18)
    let glassPath = NSBezierPath(ovalIn: glassRect)
    
    // Shadow for depth
    context?.setShadow(offset: CGSize(width: 0, height: -size * 0.03), blur: size * 0.05, color: NSColor.black.withAlphaComponent(0.5).cgColor)
    
    // Glass background: semi-transparent white
    NSColor(white: 1.0, alpha: 0.07).setFill()
    glassPath.fill()
    context?.restoreGState()
    
    // Glass highlight/glare
    context?.saveGState()
    glassPath.addClip()
    let glareColors = [
        NSColor(white: 1.0, alpha: 0.25).cgColor,
        NSColor(white: 1.0, alpha: 0.0).cgColor
    ] as CFArray
    if let glareGradient = CGGradient(colorsSpace: colorSpace, colors: glareColors, locations: [0.0, 1.0]) {
        context?.drawLinearGradient(glareGradient, start: CGPoint(x: size/2, y: size * 0.82), end: CGPoint(x: size/2, y: size * 0.5), options: [])
    }
    context?.restoreGState()
    
    // Glass stroke (thin premium white border)
    context?.saveGState()
    glassPath.lineWidth = size * 0.015
    NSColor(white: 1.0, alpha: 0.35).setStroke()
    glassPath.stroke()
    context?.restoreGState()
    
    // --- 4. Language Symbol Text (A & 🌐 or Switch arrows) ---
    // Let's draw letters 'A' (English) and 'Ctrl' (representing Control keys) or a beautiful abstract switcher icon.
    // Let's write 'Ctrl' on top and a switch loop.
    let fontName = "HelveticaNeue-Bold"
    
    // Draw "A" (representing English) on the left
    let textA = "A" as NSString
    let fontA = NSFont(name: fontName, size: size * 0.18) ?? NSFont.systemFont(ofSize: size * 0.18, weight: .bold)
    let attrsA: [NSAttributedString.Key: Any] = [
        .font: fontA,
        .foregroundColor: NSColor(red: 0.0, green: 0.85, blue: 1.0, alpha: 0.9)
    ]
    let sizeA = textA.size(withAttributes: attrsA)
    let rectA = NSRect(
        x: size * 0.34 - sizeA.width / 2,
        y: size * 0.5 - sizeA.height / 2,
        width: sizeA.width,
        height: sizeA.height
    )
    textA.draw(in: rectA, withAttributes: attrsA)
    
    // Draw "RU" or "UA" (representing other layouts) on the right
    let textR = "🇺🇦" as NSString // Let's draw Flag or Ukrainian/Russian stylized symbols. Or simply "Я"
    let textRU = "Я" as NSString
    let fontRU = NSFont(name: fontName, size: size * 0.18) ?? NSFont.systemFont(ofSize: size * 0.18, weight: .bold)
    let attrsRU: [NSAttributedString.Key: Any] = [
        .font: fontRU,
        .foregroundColor: NSColor(red: 1.0, green: 0.3, blue: 0.6, alpha: 0.9)
    ]
    let sizeRU = textRU.size(withAttributes: attrsRU)
    let rectRU = NSRect(
        x: size * 0.66 - sizeRU.width / 2,
        y: size * 0.5 - sizeRU.height / 2,
        width: sizeRU.width,
        height: sizeRU.height
    )
    textRU.draw(in: rectRU, withAttributes: attrsRU)
    
    // Draw switch arrows in the middle
    context?.saveGState()
    context?.setStrokeColor(NSColor(white: 1.0, alpha: 0.6).cgColor)
    context?.setLineWidth(size * 0.02)
    context?.setLineCap(.round)
    
    // Arrow top: left to right
    let arrowTop = NSBezierPath()
    arrowTop.move(to: NSPoint(x: size * 0.44, y: size * 0.54))
    arrowTop.line(to: NSPoint(x: size * 0.56, y: size * 0.54))
    arrowTop.line(to: NSPoint(x: size * 0.52, y: size * 0.58))
    arrowTop.stroke()
    
    // Arrow bottom: right to left
    let arrowBottom = NSBezierPath()
    arrowBottom.move(to: NSPoint(x: size * 0.56, y: size * 0.46))
    arrowBottom.line(to: NSPoint(x: size * 0.44, y: size * 0.46))
    arrowBottom.line(to: NSPoint(x: size * 0.48, y: size * 0.42))
    arrowBottom.stroke()
    
    context?.restoreGState()
    
    // Draw "Ctrl" label at the bottom of the glass disc
    let textCtrl = "ctrl" as NSString
    let fontCtrl = NSFont(name: "HelveticaNeue-Medium", size: size * 0.08) ?? NSFont.systemFont(ofSize: size * 0.08, weight: .medium)
    let attrsCtrl: [NSAttributedString.Key: Any] = [
        .font: fontCtrl,
        .foregroundColor: NSColor(white: 1.0, alpha: 0.5)
    ]
    let sizeCtrl = textCtrl.size(withAttributes: attrsCtrl)
    let rectCtrl = NSRect(
        x: size/2 - sizeCtrl.width/2,
        y: size * 0.26 - sizeCtrl.height/2,
        width: sizeCtrl.width,
        height: sizeCtrl.height
    )
    textCtrl.draw(in: rectCtrl, withAttributes: attrsCtrl)
    
    image.unlockFocus()
    return image
}

let arguments = CommandLine.arguments
guard arguments.count > 1 else {
    print("Usage: swift generate_icon.swift <output_path>")
    exit(1)
}

let outputPath = arguments[1]
let iconImage = drawMasterIcon(size: 1024)

if let tiffData = iconImage.tiffRepresentation,
   let bitmapRep = NSBitmapImageRep(data: tiffData),
   let pngData = bitmapRep.representation(using: .png, properties: [:]) {
    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Master icon successfully generated at \(outputPath)")
    } catch {
        print("Failed to write PNG data: \(error)")
        exit(1)
    }
} else {
    print("Failed to generate PNG representation")
    exit(1)
}
