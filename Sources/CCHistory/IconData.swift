import AppKit

extension NSImage {
  static let cchistoryLogo: NSImage = {
    // Create high-resolution image for Retina displays
    let size = NSSize(width: 22, height: 22)
    let image = NSImage(size: size)
    image.isTemplate = true  // Template icon: adapts to system theme

    image.lockFocus()

    // Enable anti-aliasing for smooth edges
    NSGraphicsContext.current?.imageInterpolation = .high

    // Draw speech bubble outline with clock inside
    // Using clean stroke-based design for better template icon rendering

    // Speech bubble outline (black stroke)
    let bubblePath = NSBezierPath()
    bubblePath.move(to: NSPoint(x: 4, y: 5))
    bubblePath.line(to: NSPoint(x: 18, y: 5))
    bubblePath.line(to: NSPoint(x: 18, y: 12))
    bubblePath.line(to: NSPoint(x: 15, y: 15))
    bubblePath.line(to: NSPoint(x: 11, y: 15))
    bubblePath.line(to: NSPoint(x: 11, y: 17))
    bubblePath.line(to: NSPoint(x: 8, y: 15))
    bubblePath.line(to: NSPoint(x: 4, y: 15))
    bubblePath.close()

    NSColor(white: 0, alpha: 1.0).setStroke()
    bubblePath.lineWidth = 1.5
    bubblePath.stroke()

    // Clock circle (outline)
    let clockRect = CGRect(x: 7, y: 7, width: 8, height: 8)
    let clockPath = NSBezierPath(ovalIn: clockRect)
    NSColor(white: 0, alpha: 1.0).setStroke()
    clockPath.lineWidth = 1.2
    clockPath.stroke()

    // Clock hands
    let clockCenter = NSPoint(x: 11, y: 11)

    // Hour hand
    let hourPath = NSBezierPath()
    hourPath.move(to: clockCenter)
    hourPath.line(to: NSPoint(x: 11, y: 8.5))
    NSColor(white: 0, alpha: 1.0).setStroke()
    hourPath.lineWidth = 1.2
    hourPath.stroke()

    // Minute hand
    let minutePath = NSBezierPath()
    minutePath.move(to: clockCenter)
    minutePath.line(to: NSPoint(x: 13, y: 12))
    NSColor(white: 0, alpha: 1.0).setStroke()
    minutePath.lineWidth = 1.0
    minutePath.stroke()

    // Clock center dot
    let dotRect = CGRect(x: 10.5, y: 10.5, width: 1, height: 1)
    let dotPath = NSBezierPath(ovalIn: dotRect)
    NSColor(white: 0, alpha: 1.0).setFill()
    dotPath.fill()

    // Message dots (three dots below bubble)
    let dotY: CGFloat = 17
    let dotSpacing: CGFloat = 3
    let dotStartX: CGFloat = 7
    for i in 0..<3 {
      let dotX = dotStartX + CGFloat(i) * dotSpacing
      let msgDotRect = CGRect(x: dotX, y: dotY, width: 1.5, height: 1.5)
      let msgDotPath = NSBezierPath(ovalIn: msgDotRect)
      NSColor(white: 0, alpha: 1.0).setFill()
      msgDotPath.fill()
    }

    image.unlockFocus()

    // Ensure the image is resizable with proper scaling
    image.resizingMode = .stretch
    return image
  }()
}
