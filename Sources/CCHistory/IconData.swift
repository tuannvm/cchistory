import AppKit

extension NSImage {
    static let cchistoryLogo: NSImage = {
        // Create image with proper size for menu bar
        let size = NSSize(width: 22, height: 22)
        let image = NSImage(size: size)
        image.isTemplate = false  // Important: preserve colors

        image.lockFocus()

        // Fill entire background with dark color first
        NSColor(red: 0.1, green: 0.1, blue: 0.1, alpha: 1.0).setFill()
        NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

        // Draw rounded square background (dark)
        let rect = CGRect(x: 1, y: 1, width: 20, height: 20)
        let path = NSBezierPath(roundedRect: rect, xRadius: 5, yRadius: 5)
        NSColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0).setFill()
        path.fill()

        // Draw speech bubble (orange)
        let bubblePath = NSBezierPath()
        bubblePath.move(to: NSPoint(x: 5, y: 6))
        bubblePath.line(to: NSPoint(x: 17, y: 6))
        bubblePath.line(to: NSPoint(x: 19, y: 8))
        bubblePath.line(to: NSPoint(x: 19, y: 13))
        bubblePath.line(to: NSPoint(x: 17, y: 15))
        bubblePath.line(to: NSPoint(x: 11, y: 15))
        bubblePath.line(to: NSPoint(x: 11, y: 17))
        bubblePath.line(to: NSPoint(x: 7, y: 15))
        bubblePath.line(to: NSPoint(x: 3, y: 15))
        bubblePath.line(to: NSPoint(x: 3, y: 8))
        bubblePath.close()

        NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1.0).setFill()
        bubblePath.fill()

        // Draw clock circle (dark)
        let clockRect = CGRect(x: 8, y: 8, width: 6, height: 6)
        let clockPath = NSBezierPath(ovalIn: clockRect)
        NSColor(white: 0.1, alpha: 0.9).setFill()
        clockPath.fill()

        // Draw clock hands
        NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1.0).setStroke()
        let clockCenter = NSPoint(x: 11, y: 11)

        let handPath = NSBezierPath()
        handPath.move(to: clockCenter)
        handPath.line(to: NSPoint(x: 11, y: 9))
        handPath.lineWidth = 1.2
        handPath.stroke()

        let minutePath = NSBezierPath()
        minutePath.move(to: clockCenter)
        minutePath.line(to: NSPoint(x: 12.5, y: 12))
        minutePath.lineWidth = 1.2
        minutePath.stroke()

        // Draw clock center dot
        let dotRect = CGRect(x: 10.5, y: 10.5, width: 1, height: 1)
        let dotPath = NSBezierPath(ovalIn: dotRect)
        NSColor(red: 0.85, green: 0.47, blue: 0.34, alpha: 1.0).setFill()
        dotPath.fill()

        // Draw four dots (messages)
        let dotPositions: [CGFloat] = [5, 8, 11, 14]
        for xPos in dotPositions {
            let msgDotRect = CGRect(x: xPos, y: 12.5, width: 1.2, height: 1.2)
            let msgDotPath = NSBezierPath(ovalIn: msgDotRect)
            NSColor(white: 0.1, alpha: 0.6).setFill()
            msgDotPath.fill()
        }

        image.unlockFocus()

        // Ensure the image is resizable
        image.resizingMode = .stretch
        return image
    }()
}
