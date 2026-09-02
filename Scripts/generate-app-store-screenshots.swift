import AppKit
import Foundation

private let canvasSize = NSSize(width: 1440, height: 900)
private let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
private let resources = root.appendingPathComponent("BunnyBar/Sources/BunnyBar/Resources/Assets.xcassets")
private let outputRoot = root.appendingPathComponent("docs/app-store/screenshots")

private let ink = NSColor(calibratedWhite: 0.10, alpha: 1)
private let mutedInk = NSColor(calibratedWhite: 0.32, alpha: 1)
private let paper = NSColor(calibratedRed: 0.965, green: 0.95, blue: 0.925, alpha: 1)
private let paperShadow = NSColor(calibratedWhite: 0.1, alpha: 0.10)

private struct Copy {
    let directory: String
    let title1: String
    let subtitle1: String
    let card1: String
    let card2: String
    let title2: String
    let subtitle2: String
    let phaseLabels: [String]
    let title3: String
    let subtitle3: String
    let menuTitle: String
    let cpu: String
    let memory: String
    let motion: String
    let launch: String
    let hide: String
    let quit: String
}

private let copies = [
    Copy(
        directory: "ja",
        title1: "画面の上を、\nロップイヤーがひと休み。",
        subtitle1: "作業を邪魔しない、小さなメニューバーの相棒。",
        card1: "CPUに合わせて\nテンポが少しだけ変わる",
        card2: "アカウント・広告・\nネットワーク通信なし",
        title2: "短い探索と、\n静かな休息。",
        subtitle2: "部屋飼いのロップイヤーらしい、控えめな半跳び。",
        phaseLabels: ["休息", "ため", "踏切", "伸び", "着地", "落ち着く"],
        title3: "必要な情報は、\nうさぎメニューに。",
        subtitle3: "CPU・メモリ・動作状態を、いつでも確認。",
        menuTitle: "BunnyBar",
        cpu: "CPU使用率        24%",
        memory: "メモリ使用率     61%",
        motion: "動作状態          Resting",
        launch: "ログイン時に起動",
        hide: "うさぎを隠す",
        quit: "BunnyBarを終了"
    ),
    Copy(
        directory: "en",
        title1: "A quiet lop-eared\ncompanion for your Mac.",
        subtitle1: "A tiny menu-bar rabbit that stays out of your way.",
        card1: "Its pace changes\nsubtly with CPU activity",
        card2: "No accounts, ads,\nanalytics, or networking",
        title2: "Short explorations.\nQuiet rests.",
        subtitle2: "A restrained half-bound inspired by indoor lop rabbits.",
        phaseLabels: ["Rest", "Gather", "Launch", "Stretch", "Land", "Settle"],
        title3: "Useful details,\ninside the rabbit menu.",
        subtitle3: "Check CPU, memory, motion, and speed at any time.",
        menuTitle: "BunnyBar",
        cpu: "CPU usage          24%",
        memory: "Memory usage       61%",
        motion: "Motion             Resting",
        launch: "Launch at Login",
        hide: "Hide Bunny",
        quit: "Quit BunnyBar"
    )
]

private func image(at url: URL) -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        fatalError("Could not load \(url.path)")
    }
    return image
}

private let resting = image(at: resources.appendingPathComponent("LopRabbit.imageset/lop-rabbit@2x.png"))
private let motionSheet = image(at: resources.appendingPathComponent("NaturalHop.imageset/natural-hop@2x.png"))
private let statusRabbit = image(at: resources.appendingPathComponent("StatusRabbit.imageset/status-rabbit@2x.png"))

private func drawText(
    _ value: String,
    in rect: NSRect,
    size: CGFloat,
    weight: NSFont.Weight = .regular,
    color: NSColor = ink,
    alignment: NSTextAlignment = .left,
    lineHeight: CGFloat? = nil
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    if let lineHeight {
        paragraph.minimumLineHeight = lineHeight
        paragraph.maximumLineHeight = lineHeight
    }
    (value as NSString).draw(
        in: rect,
        withAttributes: [
            .font: NSFont.systemFont(ofSize: size, weight: weight),
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    )
}

private func roundedRect(_ rect: NSRect, radius: CGFloat, fill: NSColor, stroke: NSColor? = nil) {
    let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    fill.setFill()
    path.fill()
    if let stroke {
        stroke.setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

private func drawTinted(
    _ source: NSImage,
    from sourceRect: NSRect? = nil,
    in destination: NSRect,
    color: NSColor = ink
) {
    guard let context = NSGraphicsContext.current else { return }
    context.saveGraphicsState()
    context.cgContext.beginTransparencyLayer(auxiliaryInfo: nil)
    source.draw(
        in: destination,
        from: sourceRect ?? NSRect(origin: .zero, size: source.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: true,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    context.cgContext.setBlendMode(.sourceIn)
    color.setFill()
    context.cgContext.fill(destination)
    context.cgContext.endTransparencyLayer()
    context.restoreGraphicsState()
}

private func drawBackground() {
    let gradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.985, green: 0.975, blue: 0.955, alpha: 1),
        NSColor(calibratedRed: 0.89, green: 0.86, blue: 0.81, alpha: 1)
    ])!
    gradient.draw(in: NSRect(origin: .zero, size: canvasSize), angle: -28)

    let glow = NSGradient(colorsAndLocations:
        (NSColor(calibratedWhite: 1, alpha: 0.78), 0),
        (NSColor(calibratedWhite: 1, alpha: 0), 1)
    )!
    glow.draw(in: NSBezierPath(ovalIn: NSRect(x: 780, y: 410, width: 760, height: 760)), relativeCenterPosition: .zero)
}

private func drawMenuBar(rabbitX: CGFloat) {
    NSColor(calibratedWhite: 1, alpha: 0.58).setFill()
    NSRect(x: 0, y: 856, width: 1440, height: 44).fill()
    NSColor(calibratedWhite: 0, alpha: 0.08).setFill()
    NSRect(x: 0, y: 855, width: 1440, height: 1).fill()
    drawText("BunnyBar", in: NSRect(x: 34, y: 866, width: 170, height: 24), size: 16, weight: .semibold)
    drawTinted(statusRabbit, in: NSRect(x: 1322, y: 862, width: 44, height: 36))
    drawText("10:08", in: NSRect(x: 1368, y: 866, width: 58, height: 22), size: 14, color: mutedInk, alignment: .right)
    drawTinted(resting, in: NSRect(x: rabbitX, y: 812, width: 128, height: 62))
}

private func drawFeatureCard(_ text: String, rect: NSRect, number: String) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = paperShadow
    shadow.shadowBlurRadius = 20
    shadow.shadowOffset = NSSize(width: 0, height: -8)
    shadow.set()
    roundedRect(rect, radius: 24, fill: NSColor(calibratedWhite: 1, alpha: 0.72))
    NSGraphicsContext.current?.restoreGraphicsState()

    drawText(number, in: NSRect(x: rect.minX + 28, y: rect.maxY - 54, width: 45, height: 30), size: 16, weight: .semibold, color: mutedInk)
    drawText(text, in: NSRect(x: rect.minX + 28, y: rect.minY + 30, width: rect.width - 56, height: 100), size: 22, weight: .medium, lineHeight: 31)
}

private func render(_ draw: () -> Void) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvasSize.width),
        pixelsHigh: Int(canvasSize.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    )!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

private func write(_ rep: NSBitmapImageRep, to url: URL) {
    try! FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let data = rep.representation(using: .png, properties: [.compressionFactor: 0.82]) else {
        fatalError("Could not encode screenshot")
    }
    try! data.write(to: url)
    print("Wrote \(url.path)")
}

private func screenshotOne(_ copy: Copy) -> NSBitmapImageRep {
    render {
        drawBackground()
        drawMenuBar(rabbitX: 1050)
        drawText(copy.title1, in: NSRect(x: 90, y: 530, width: 790, height: 230), size: 62, weight: .bold, lineHeight: 78)
        drawText(copy.subtitle1, in: NSRect(x: 94, y: 475, width: 760, height: 50), size: 23, color: mutedInk)
        drawFeatureCard(copy.card1, rect: NSRect(x: 90, y: 126, width: 390, height: 214), number: "01")
        drawFeatureCard(copy.card2, rect: NSRect(x: 510, y: 126, width: 390, height: 214), number: "02")

        roundedRect(NSRect(x: 1000, y: 168, width: 310, height: 310), radius: 155, fill: NSColor(calibratedWhite: 1, alpha: 0.52), stroke: NSColor(calibratedWhite: 0, alpha: 0.08))
        drawTinted(resting, in: NSRect(x: 1027, y: 242, width: 256, height: 124))
    }
}

private func screenshotTwo(_ copy: Copy) -> NSBitmapImageRep {
    render {
        drawBackground()
        drawMenuBar(rabbitX: 870)
        drawText(copy.title2, in: NSRect(x: 90, y: 606, width: 760, height: 170), size: 58, weight: .bold, lineHeight: 72)
        drawText(copy.subtitle2, in: NSRect(x: 94, y: 552, width: 890, height: 46), size: 22, color: mutedInk)

        let frameWidth = motionSheet.size.width / 6
        for index in 0..<6 {
            let x = 85 + CGFloat(index) * 218
            let lift: CGFloat = [0, 14, 66, 92, 28, 4][index]
            roundedRect(NSRect(x: x, y: 150 + lift, width: 182, height: 190), radius: 24, fill: NSColor(calibratedWhite: 1, alpha: 0.68), stroke: NSColor(calibratedWhite: 0, alpha: 0.06))
            let source = NSRect(x: CGFloat(index) * frameWidth, y: 0, width: frameWidth, height: motionSheet.size.height)
            drawTinted(motionSheet, from: source, in: NSRect(x: x + 12, y: 216 + lift, width: 158, height: 77))
            drawText(copy.phaseLabels[index], in: NSRect(x: x + 10, y: 176 + lift, width: 162, height: 28), size: 15, weight: .medium, color: mutedInk, alignment: .center)
        }
    }
}

private func drawMenu(_ copy: Copy, rect: NSRect) {
    NSGraphicsContext.current?.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(calibratedWhite: 0, alpha: 0.22)
    shadow.shadowBlurRadius = 34
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    roundedRect(rect, radius: 18, fill: NSColor(calibratedWhite: 0.98, alpha: 0.96), stroke: NSColor(calibratedWhite: 0, alpha: 0.12))
    NSGraphicsContext.current?.restoreGraphicsState()

    drawTinted(statusRabbit, in: NSRect(x: rect.minX + 28, y: rect.maxY - 72, width: 44, height: 36))
    drawText(copy.menuTitle, in: NSRect(x: rect.minX + 86, y: rect.maxY - 67, width: rect.width - 115, height: 34), size: 21, weight: .semibold)

    let rows = [copy.cpu, copy.memory, copy.motion]
    for (index, row) in rows.enumerated() {
        drawText(row, in: NSRect(x: rect.minX + 34, y: rect.maxY - 130 - CGFloat(index) * 42, width: rect.width - 68, height: 30), size: 18, color: ink)
    }

    NSColor(calibratedWhite: 0, alpha: 0.10).setFill()
    NSRect(x: rect.minX + 20, y: rect.maxY - 268, width: rect.width - 40, height: 1).fill()
    let controls = [copy.launch, copy.hide, copy.quit]
    for (index, row) in controls.enumerated() {
        drawText(row, in: NSRect(x: rect.minX + 34, y: rect.maxY - 322 - CGFloat(index) * 50, width: rect.width - 68, height: 32), size: 18, color: index == 2 ? NSColor.systemRed : ink)
    }
}

private func screenshotThree(_ copy: Copy) -> NSBitmapImageRep {
    render {
        drawBackground()
        drawMenuBar(rabbitX: 1060)
        drawText(copy.title3, in: NSRect(x: 88, y: 584, width: 690, height: 190), size: 58, weight: .bold, lineHeight: 72)
        drawText(copy.subtitle3, in: NSRect(x: 94, y: 526, width: 710, height: 48), size: 22, color: mutedInk)

        drawMenu(copy, rect: NSRect(x: 860, y: 160, width: 430, height: 560))
        drawTinted(resting, in: NSRect(x: 135, y: 230, width: 384, height: 186))
    }
}

for copy in copies {
    let directory = outputRoot.appendingPathComponent(copy.directory)
    write(screenshotOne(copy), to: directory.appendingPathComponent("01-companion.png"))
    write(screenshotTwo(copy), to: directory.appendingPathComponent("02-natural-motion.png"))
    write(screenshotThree(copy), to: directory.appendingPathComponent("03-menu-details.png"))
}
