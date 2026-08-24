import AppKit

/// The menu bar mark, drawn rather than embedded.
///
/// Flagged `isTemplate`, so macOS tints one silhouette for both appearances.
///
/// It carries one value — how much is spent — plus one bit for over pace. A
/// positional pace marker was illegible at 18pt; a state change is not.
enum Mark {

    enum Style: String {
        case ring, disc, jar, bars
        static func fromEnvironment() -> Style {
            Style(rawValue: ProcessInfo.processInfo.environment["RATION_MARK"] ?? "") ?? .disc
        }
    }

    /// - Parameters:
    ///   - used: 0–100, how much of the window is spent. Fill grows with this,
    ///           so ink tracks alarm rather than tracking comfort.
    ///   - overPace: whether the week is being burned faster than it elapses.
    /// Last drawing, keyed by everything that changes it. The mark only moves
    /// in whole percent, so a redraw per tick is redrawing the same pixels.
    private static var cache: (key: String, image: NSImage)?

    static func image(style: Style, used: Double, overPace: Bool, size: CGFloat = 16) -> NSImage {
        let key = "\(style.rawValue)-\(Int(used.rounded()))-\(overPace)-\(size)"
        if let cache, cache.key == key { return cache.image }
        let drawn = draw(style: style, used: used, overPace: overPace, size: size)
        cache = (key, drawn)
        return drawn
    }

    private static func draw(style: Style, used: Double, overPace: Bool, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            NSColor.black.set()
            let u = max(0, min(100, used))
            switch style {
            case .ring: drawRing(rect, u, overPace)
            case .disc: drawDisc(rect, u, overPace)
            case .jar:  drawJar(rect, u, overPace)
            case .bars: drawBars(rect, u, overPace)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - Styles

    private static func drawRing(_ r: NSRect, _ used: Double, _ over: Bool) {
        let c = NSPoint(x: r.midX, y: r.midY)
        let radius = r.width * 0.36
        let width = r.width * 0.15

        // Unspent portion, kept faint so an idle menu bar stays quiet.
        let track = NSBezierPath()
        track.appendArc(withCenter: c, radius: radius, startAngle: 0, endAngle: 360)
        track.lineWidth = width
        NSColor.black.withAlphaComponent(0.2).setStroke()
        track.stroke()

        if used > 0.5 {
            NSColor.black.setStroke()
            let spent = NSBezierPath()
            // Clockwise from twelve o'clock, the way a clock face is read.
            spent.appendArc(withCenter: c, radius: radius,
                            startAngle: 90, endAngle: 90 - (used / 100 * 359.9), clockwise: true)
            spent.lineWidth = width
            spent.stroke()
        }

        if over {
            NSColor.black.setFill()
            let d = r.width * 0.17
            NSBezierPath(ovalIn: NSRect(x: c.x - d / 2, y: c.y - d / 2, width: d, height: d)).fill()
        }
    }

    private static func drawDisc(_ r: NSRect, _ used: Double, _ over: Bool) {
        let c = NSPoint(x: r.midX, y: r.midY)
        let radius = r.width * 0.33
        NSColor.black.setStroke()

        let outline = NSBezierPath(ovalIn: NSRect(x: c.x - radius, y: c.y - radius,
                                                  width: radius * 2, height: radius * 2))
        outline.lineWidth = r.width * 0.055
        outline.stroke()

        guard used > 0.5 else { return }

        NSColor.black.setFill()
        let wedge = NSBezierPath()
        wedge.move(to: c)
        wedge.appendArc(withCenter: c, radius: radius,
                        startAngle: 90, endAngle: 90 - (min(used, 99.9) / 100 * 360), clockwise: true)
        wedge.close()

        if over {
            // Over-pace is counter-punched OUT of the wedge rather than added
            // around it. A halo outside the disc grew the bounding box, so the
            // status item jumped sideways the moment pace flipped — motion in
            // the menu bar reads as a glitch. Even-odd winding puts the signal
            // inside the footprint the mark already occupies.
            let hole = r.width * 0.15
            wedge.appendOval(in: NSRect(x: c.x - hole, y: c.y - hole, width: hole * 2, height: hole * 2))
            wedge.windingRule = .evenOdd
        }
        wedge.fill()
    }

    private static func drawJar(_ r: NSRect, _ used: Double, _ over: Bool) {
        let w = r.width * 0.53, h = r.width * 0.61
        let box = NSRect(x: r.midX - w / 2, y: r.midY - h / 2, width: w, height: h)
        NSColor.black.setStroke()
        let outline = NSBezierPath(roundedRect: box, xRadius: r.width * 0.09, yRadius: r.width * 0.09)
        outline.lineWidth = r.width * 0.067
        outline.stroke()
        let inset = r.width * 0.095
        let inner = box.insetBy(dx: inset, dy: inset)
        let fh = inner.height * used / 100
        if fh > 0.5 {
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: inner.minX, y: inner.minY, width: inner.width, height: fh),
                         xRadius: r.width * 0.04, yRadius: r.width * 0.04).fill()
        }
        if over {
            NSColor.black.setFill()
            NSBezierPath(roundedRect: NSRect(x: box.minX - r.width * 0.04, y: box.maxY + r.width * 0.09,
                                             width: w + r.width * 0.08, height: r.width * 0.072),
                         xRadius: r.width * 0.036, yRadius: r.width * 0.036).fill()
        }
    }

    private static func drawBars(_ r: NSRect, _ used: Double, _ over: Bool) {
        let n = 3
        let w = r.width * 0.55, bh = r.width * 0.167, gap = r.width * 0.067
        let total = CGFloat(n) * bh + CGFloat(n - 1) * gap
        let x = r.midX - w / 2
        let y0 = r.midY - total / 2
        let lit = min(n, Int(ceil(used / 100 * Double(n))))
        for i in 0..<n {
            let rect = NSRect(x: x, y: y0 + CGFloat(i) * (bh + gap), width: w, height: bh)
            let path = NSBezierPath(roundedRect: rect, xRadius: bh / 2, yRadius: bh / 2)
            if i < lit {
                NSColor.black.setFill()
                path.fill()
            } else {
                NSColor.black.withAlphaComponent(0.35).setStroke()
                path.lineWidth = r.width * 0.05
                path.stroke()
            }
        }
        if over {
            NSColor.black.setFill()
            let d = r.width * 0.17
            NSBezierPath(ovalIn: NSRect(x: x + w + r.width * 0.05, y: y0 + total - d,
                                        width: d, height: d)).fill()
        }
    }
}
