import SwiftUI

/// Animals for the lakeshore background, drawn in the bold outlined Woodland style of the art Bhavik
/// shared. They are new drawings (eagle, moose, bear, loon, turtle, fish), not traced from the painting.
/// Generated from docs/theme/animals.json; each animal is in its own coordinate space of `size`.
struct LakeshoreAnimal: Sendable {
    struct Part: Sendable {
        /// nil draws the outline only (for example the fish's gill line).
        let fill: Color?
        let path: Path
        init(fill: Color?, _ build: (inout Path) -> Void) {
            self.fill = fill
            var path = Path()
            build(&path)
            self.path = path
        }
    }

    let size: CGSize
    let parts: [Part]

    /// Draws the animal into `rect` (keeping its aspect ratio, bottom-aligned), optionally facing the other way.
    func draw(in context: GraphicsContext, rect: CGRect, outline: Color, flipped: Bool = false) {
        let scale = min(rect.width / size.width, rect.height / size.height)
        var ctx = context
        ctx.translateBy(x: flipped ? rect.minX + size.width * scale : rect.minX, y: rect.maxY - size.height * scale)
        ctx.scaleBy(x: flipped ? -scale : scale, y: scale)
        let line = StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round)
        for part in parts {
            if let fill = part.fill { ctx.fill(part.path, with: .color(fill)) }
            ctx.stroke(part.path, with: .color(outline), style: line)
        }
    }
}

extension LakeshoreAnimal {
    static let eagle = LakeshoreAnimal(size: CGSize(width: 240, height: 140), parts: [
        .init(fill: Color(uiColor: UIColor(rgb: 0x6B3A1A))) { p in p.move(to: .init(x: 110, y: 70)); p.addCurve(to: .init(x: 150, y: 10), control1: .init(x: 100, y: 40), control2: .init(x: 120, y: 18)); p.addLine(to: .init(x: 148, y: 22)); p.addLine(to: .init(x: 165, y: 12)); p.addLine(to: .init(x: 160, y: 26)); p.addLine(to: .init(x: 178, y: 18)); p.addLine(to: .init(x: 170, y: 32)); p.addLine(to: .init(x: 188, y: 28)); p.addLine(to: .init(x: 176, y: 44)); p.addCurve(to: .init(x: 110, y: 70), control1: .init(x: 160, y: 58), control2: .init(x: 135, y: 66)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x7A4524))) { p in p.move(to: .init(x: 60, y: 78)); p.addCurve(to: .init(x: 165, y: 72), control1: .init(x: 80, y: 62), control2: .init(x: 130, y: 60)); p.addCurve(to: .init(x: 168, y: 98), control1: .init(x: 180, y: 78), control2: .init(x: 182, y: 92)); p.addCurve(to: .init(x: 60, y: 92), control1: .init(x: 135, y: 108), control2: .init(x: 90, y: 104)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.move(to: .init(x: 62, y: 80)); p.addLine(to: .init(x: 28, y: 70)); p.addLine(to: .init(x: 34, y: 82)); p.addLine(to: .init(x: 22, y: 88)); p.addLine(to: .init(x: 36, y: 92)); p.addLine(to: .init(x: 30, y: 102)); p.addLine(to: .init(x: 64, y: 92)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.move(to: .init(x: 160, y: 72)); p.addCurve(to: .init(x: 204, y: 70), control1: .init(x: 170, y: 60), control2: .init(x: 194, y: 58)); p.addCurve(to: .init(x: 198, y: 84), control1: .init(x: 208, y: 76), control2: .init(x: 206, y: 82)); p.addCurve(to: .init(x: 162, y: 92), control1: .init(x: 188, y: 88), control2: .init(x: 172, y: 88)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF2B233))) { p in p.move(to: .init(x: 200, y: 68)); p.addCurve(to: .init(x: 220, y: 82), control1: .init(x: 212, y: 66), control2: .init(x: 222, y: 72)); p.addCurve(to: .init(x: 200, y: 82), control1: .init(x: 214, y: 80), control2: .init(x: 208, y: 80)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x132743))) { p in p.addEllipse(in: CGRect(x: 189, y: 67, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0x8E532B))) { p in p.move(to: .init(x: 90, y: 84)); p.addCurve(to: .init(x: 80, y: 130), control1: .init(x: 100, y: 100), control2: .init(x: 96, y: 118)); p.addLine(to: .init(x: 92, y: 128)); p.addLine(to: .init(x: 86, y: 138)); p.addLine(to: .init(x: 102, y: 132)); p.addLine(to: .init(x: 100, y: 140)); p.addLine(to: .init(x: 114, y: 130)); p.addCurve(to: .init(x: 120, y: 86), control1: .init(x: 126, y: 116), control2: .init(x: 128, y: 98)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF2B233))) { p in p.move(to: .init(x: 120, y: 100)); p.addLine(to: .init(x: 118, y: 112)); p.addLine(to: .init(x: 128, y: 112)); p.addLine(to: .init(x: 126, y: 100)); p.closeSubpath() },
    ])

    static let moose = LakeshoreAnimal(size: CGSize(width: 220, height: 190), parts: [
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.move(to: .init(x: 156, y: 48)); p.addCurve(to: .init(x: 142, y: 12), control1: .init(x: 142, y: 38), control2: .init(x: 136, y: 22)); p.addCurve(to: .init(x: 158, y: 16), control1: .init(x: 148, y: 24), control2: .init(x: 154, y: 26)); p.addCurve(to: .init(x: 172, y: 18), control1: .init(x: 162, y: 28), control2: .init(x: 166, y: 30)); p.addCurve(to: .init(x: 186, y: 24), control1: .init(x: 174, y: 32), control2: .init(x: 178, y: 34)); p.addCurve(to: .init(x: 162, y: 56), control1: .init(x: 186, y: 40), control2: .init(x: 176, y: 52)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.move(to: .init(x: 180, y: 52)); p.addCurve(to: .init(x: 204, y: 18), control1: .init(x: 194, y: 44), control2: .init(x: 204, y: 32)); p.addCurve(to: .init(x: 192, y: 18), control1: .init(x: 196, y: 28), control2: .init(x: 192, y: 28)); p.addCurve(to: .init(x: 180, y: 22), control1: .init(x: 186, y: 30), control2: .init(x: 182, y: 32)); p.addCurve(to: .init(x: 170, y: 48), control1: .init(x: 176, y: 34), control2: .init(x: 174, y: 40)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x5E3519))) { p in p.move(to: .init(x: 50, y: 120)); p.addLine(to: .init(x: 46, y: 180)); p.addLine(to: .init(x: 58, y: 180)); p.addLine(to: .init(x: 62, y: 122)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x5E3519))) { p in p.move(to: .init(x: 132, y: 120)); p.addLine(to: .init(x: 134, y: 180)); p.addLine(to: .init(x: 146, y: 180)); p.addLine(to: .init(x: 146, y: 122)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x8A5A2E))) { p in p.move(to: .init(x: 30, y: 96)); p.addCurve(to: .init(x: 92, y: 64), control1: .init(x: 30, y: 74), control2: .init(x: 56, y: 62)); p.addCurve(to: .init(x: 148, y: 64), control1: .init(x: 110, y: 56), control2: .init(x: 132, y: 54)); p.addCurve(to: .init(x: 154, y: 118), control1: .init(x: 160, y: 72), control2: .init(x: 162, y: 96)); p.addCurve(to: .init(x: 40, y: 124), control1: .init(x: 140, y: 130), control2: .init(x: 60, y: 132)); p.addCurve(to: .init(x: 30, y: 96), control1: .init(x: 32, y: 118), control2: .init(x: 30, y: 108)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x7A4A26))) { p in p.move(to: .init(x: 64, y: 120)); p.addLine(to: .init(x: 62, y: 182)); p.addLine(to: .init(x: 74, y: 182)); p.addLine(to: .init(x: 78, y: 122)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x7A4A26))) { p in p.move(to: .init(x: 146, y: 116)); p.addLine(to: .init(x: 152, y: 180)); p.addLine(to: .init(x: 164, y: 180)); p.addLine(to: .init(x: 158, y: 112)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x7A4A26))) { p in p.move(to: .init(x: 146, y: 62)); p.addCurve(to: .init(x: 182, y: 50), control1: .init(x: 156, y: 52), control2: .init(x: 170, y: 46)); p.addCurve(to: .init(x: 212, y: 78), control1: .init(x: 194, y: 54), control2: .init(x: 206, y: 66)); p.addCurve(to: .init(x: 202, y: 90), control1: .init(x: 216, y: 86), control2: .init(x: 210, y: 92)); p.addCurve(to: .init(x: 182, y: 90), control1: .init(x: 194, y: 88), control2: .init(x: 188, y: 86)); p.addCurve(to: .init(x: 164, y: 100), control1: .init(x: 178, y: 100), control2: .init(x: 170, y: 104)); p.addCurve(to: .init(x: 146, y: 62), control1: .init(x: 156, y: 90), control2: .init(x: 152, y: 78)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x6B3A1A))) { p in p.move(to: .init(x: 170, y: 98)); p.addCurve(to: .init(x: 176, y: 118), control1: .init(x: 168, y: 108), control2: .init(x: 172, y: 116)); p.addCurve(to: .init(x: 178, y: 96), control1: .init(x: 180, y: 112), control2: .init(x: 180, y: 104)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x132743))) { p in p.addEllipse(in: CGRect(x: 189, y: 61, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xC98A4B))) { p in p.move(to: .init(x: 60, y: 86)); p.addCurve(to: .init(x: 110, y: 88), control1: .init(x: 76, y: 76), control2: .init(x: 98, y: 78)); p.addCurve(to: .init(x: 74, y: 96), control1: .init(x: 96, y: 86), control2: .init(x: 84, y: 88)); p.addCurve(to: .init(x: 102, y: 108), control1: .init(x: 86, y: 96), control2: .init(x: 96, y: 100)); p.addCurve(to: .init(x: 58, y: 110), control1: .init(x: 86, y: 104), control2: .init(x: 70, y: 104)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x6B3A1A))) { p in p.move(to: .init(x: 30, y: 92)); p.addLine(to: .init(x: 22, y: 100)); p.addLine(to: .init(x: 32, y: 104)); p.closeSubpath() },
    ])

    static let bear = LakeshoreAnimal(size: CGSize(width: 230, height: 140), parts: [
        .init(fill: Color(uiColor: UIColor(rgb: 0x2B2B30))) { p in p.move(to: .init(x: 40, y: 90)); p.addLine(to: .init(x: 36, y: 132)); p.addLine(to: .init(x: 52, y: 132)); p.addLine(to: .init(x: 56, y: 96)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x2B2B30))) { p in p.move(to: .init(x: 150, y: 92)); p.addLine(to: .init(x: 150, y: 132)); p.addLine(to: .init(x: 166, y: 132)); p.addLine(to: .init(x: 166, y: 94)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x3A3A42))) { p in p.move(to: .init(x: 30, y: 70)); p.addCurve(to: .init(x: 100, y: 32), control1: .init(x: 30, y: 44), control2: .init(x: 60, y: 30)); p.addCurve(to: .init(x: 176, y: 50), control1: .init(x: 130, y: 34), control2: .init(x: 160, y: 36)); p.addCurve(to: .init(x: 180, y: 98), control1: .init(x: 188, y: 60), control2: .init(x: 190, y: 82)); p.addCurve(to: .init(x: 46, y: 104), control1: .init(x: 160, y: 110), control2: .init(x: 70, y: 112)); p.addCurve(to: .init(x: 30, y: 70), control1: .init(x: 34, y: 98), control2: .init(x: 30, y: 86)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x3A3A42))) { p in p.move(to: .init(x: 64, y: 98)); p.addLine(to: .init(x: 64, y: 134)); p.addLine(to: .init(x: 80, y: 134)); p.addLine(to: .init(x: 84, y: 100)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x3A3A42))) { p in p.move(to: .init(x: 166, y: 92)); p.addLine(to: .init(x: 172, y: 134)); p.addLine(to: .init(x: 188, y: 134)); p.addLine(to: .init(x: 182, y: 90)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x3A3A42))) { p in p.move(to: .init(x: 170, y: 48)); p.addCurve(to: .init(x: 206, y: 44), control1: .init(x: 178, y: 38), control2: .init(x: 196, y: 36)); p.addCurve(to: .init(x: 224, y: 66), control1: .init(x: 214, y: 50), control2: .init(x: 222, y: 58)); p.addCurve(to: .init(x: 208, y: 78), control1: .init(x: 226, y: 74), control2: .init(x: 218, y: 78)); p.addCurve(to: .init(x: 178, y: 80), control1: .init(x: 200, y: 86), control2: .init(x: 186, y: 86)); p.addCurve(to: .init(x: 170, y: 48), control1: .init(x: 170, y: 74), control2: .init(x: 166, y: 60)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xB08A5A))) { p in p.move(to: .init(x: 206, y: 58)); p.addCurve(to: .init(x: 224, y: 68), control1: .init(x: 214, y: 58), control2: .init(x: 222, y: 62)); p.addCurve(to: .init(x: 206, y: 72), control1: .init(x: 220, y: 74), control2: .init(x: 212, y: 76)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x132743))) { p in p.addEllipse(in: CGRect(x: 221, y: 63, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0x3A3A42))) { p in p.move(to: .init(x: 180, y: 44)); p.addCurve(to: .init(x: 190, y: 36), control1: .init(x: 178, y: 34), control2: .init(x: 184, y: 30)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 197, y: 53, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0x5E5E6A))) { p in p.move(to: .init(x: 80, y: 50)); p.addCurve(to: .init(x: 130, y: 52), control1: .init(x: 96, y: 44), control2: .init(x: 116, y: 44)); p.addCurve(to: .init(x: 96, y: 64), control1: .init(x: 116, y: 52), control2: .init(x: 104, y: 56)); p.addCurve(to: .init(x: 126, y: 76), control1: .init(x: 110, y: 64), control2: .init(x: 120, y: 68)); p.addCurve(to: .init(x: 80, y: 78), control1: .init(x: 108, y: 72), control2: .init(x: 92, y: 72)); p.closeSubpath() },
    ])

    static let loon = LakeshoreAnimal(size: CGSize(width: 200, height: 90), parts: [
        .init(fill: Color(uiColor: UIColor(rgb: 0x1E2228))) { p in p.move(to: .init(x: 20, y: 60)); p.addCurve(to: .init(x: 110, y: 38), control1: .init(x: 30, y: 40), control2: .init(x: 70, y: 34)); p.addCurve(to: .init(x: 138, y: 60), control1: .init(x: 130, y: 40), control2: .init(x: 140, y: 50)); p.addCurve(to: .init(x: 20, y: 60), control1: .init(x: 120, y: 72), control2: .init(x: 50, y: 74)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x1E2228))) { p in p.move(to: .init(x: 120, y: 42)); p.addCurve(to: .init(x: 156, y: 14), control1: .init(x: 124, y: 24), control2: .init(x: 140, y: 12)); p.addCurve(to: .init(x: 170, y: 34), control1: .init(x: 168, y: 16), control2: .init(x: 174, y: 26)); p.addCurve(to: .init(x: 138, y: 52), control1: .init(x: 160, y: 36), control2: .init(x: 146, y: 40)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x1E2228))) { p in p.move(to: .init(x: 168, y: 24)); p.addLine(to: .init(x: 196, y: 28)); p.addLine(to: .init(x: 168, y: 32)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xE0332E))) { p in p.addEllipse(in: CGRect(x: 154, y: 20, width: 8, height: 8)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.move(to: .init(x: 128, y: 40)); p.addCurve(to: .init(x: 142, y: 44), control1: .init(x: 134, y: 36), control2: .init(x: 140, y: 38)); p.addCurve(to: .init(x: 128, y: 46), control1: .init(x: 138, y: 42), control2: .init(x: 132, y: 42)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 47, y: 47, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 61, y: 43, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 75, y: 45, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 89, y: 43, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 55, y: 55, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 69, y: 53, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 83, y: 53, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 97, y: 51, width: 6, height: 6)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 103, y: 43, width: 6, height: 6)) },
    ])

    static let turtle = LakeshoreAnimal(size: CGSize(width: 150, height: 150), parts: [
        .init(fill: Color(uiColor: UIColor(rgb: 0x6F9A55))) { p in p.move(to: .init(x: 75, y: 8)); p.addCurve(to: .init(x: 86, y: 30), control1: .init(x: 88, y: 8), control2: .init(x: 92, y: 22)); p.addLine(to: .init(x: 64, y: 30)); p.addCurve(to: .init(x: 75, y: 8), control1: .init(x: 58, y: 22), control2: .init(x: 62, y: 8)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x6F9A55))) { p in p.move(to: .init(x: 30, y: 44)); p.addCurve(to: .init(x: 12, y: 56), control1: .init(x: 14, y: 36), control2: .init(x: 6, y: 46)); p.addLine(to: .init(x: 34, y: 58)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x6F9A55))) { p in p.move(to: .init(x: 120, y: 44)); p.addCurve(to: .init(x: 138, y: 56), control1: .init(x: 136, y: 36), control2: .init(x: 144, y: 46)); p.addLine(to: .init(x: 116, y: 58)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x6F9A55))) { p in p.move(to: .init(x: 34, y: 104)); p.addCurve(to: .init(x: 26, y: 128), control1: .init(x: 16, y: 112), control2: .init(x: 14, y: 124)); p.addLine(to: .init(x: 42, y: 110)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x6F9A55))) { p in p.move(to: .init(x: 116, y: 104)); p.addCurve(to: .init(x: 124, y: 128), control1: .init(x: 134, y: 112), control2: .init(x: 136, y: 124)); p.addLine(to: .init(x: 108, y: 110)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x6F9A55))) { p in p.move(to: .init(x: 70, y: 124)); p.addLine(to: .init(x: 75, y: 142)); p.addLine(to: .init(x: 80, y: 124)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x3F7A3A))) { p in p.addEllipse(in: CGRect(x: 25, y: 22, width: 100, height: 108)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0x5E9A48))) { p in p.addEllipse(in: CGRect(x: 41, y: 38, width: 68, height: 76)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0x9CC36A))) { p in p.move(to: .init(x: 75, y: 50)); p.addLine(to: .init(x: 92, y: 62)); p.addLine(to: .init(x: 92, y: 88)); p.addLine(to: .init(x: 75, y: 100)); p.addLine(to: .init(x: 58, y: 88)); p.addLine(to: .init(x: 58, y: 62)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x132743))) { p in p.addEllipse(in: CGRect(x: 66.5, y: 13.5, width: 5, height: 5)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0x132743))) { p in p.addEllipse(in: CGRect(x: 78.5, y: 13.5, width: 5, height: 5)) },
    ])

    static let fish = LakeshoreAnimal(size: CGSize(width: 200, height: 90), parts: [
        .init(fill: Color(uiColor: UIColor(rgb: 0xB89B44))) { p in p.move(to: .init(x: 150, y: 46)); p.addLine(to: .init(x: 190, y: 18)); p.addLine(to: .init(x: 184, y: 46)); p.addLine(to: .init(x: 190, y: 74)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xB89B44))) { p in p.move(to: .init(x: 60, y: 24)); p.addLine(to: .init(x: 70, y: 6)); p.addLine(to: .init(x: 78, y: 22)); p.addLine(to: .init(x: 88, y: 6)); p.addLine(to: .init(x: 94, y: 22)); p.addLine(to: .init(x: 104, y: 8)); p.addLine(to: .init(x: 110, y: 26)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xD4B455))) { p in p.move(to: .init(x: 14, y: 48)); p.addCurve(to: .init(x: 120, y: 26), control1: .init(x: 30, y: 26), control2: .init(x: 80, y: 18)); p.addCurve(to: .init(x: 158, y: 46), control1: .init(x: 140, y: 30), control2: .init(x: 154, y: 40)); p.addCurve(to: .init(x: 120, y: 68), control1: .init(x: 154, y: 54), control2: .init(x: 140, y: 64)); p.addCurve(to: .init(x: 14, y: 48), control1: .init(x: 80, y: 76), control2: .init(x: 30, y: 70)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xB89B44))) { p in p.move(to: .init(x: 70, y: 62)); p.addLine(to: .init(x: 64, y: 80)); p.addLine(to: .init(x: 84, y: 66)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0x8C7A2E))) { p in p.move(to: .init(x: 40, y: 32)); p.addCurve(to: .init(x: 110, y: 36), control1: .init(x: 60, y: 30), control2: .init(x: 80, y: 30)); p.addCurve(to: .init(x: 46, y: 40), control1: .init(x: 90, y: 40), control2: .init(x: 70, y: 40)); p.closeSubpath() },
        .init(fill: Color(uiColor: UIColor(rgb: 0xF4EFE2))) { p in p.addEllipse(in: CGRect(x: 26, y: 38, width: 12, height: 12)) },
        .init(fill: Color(uiColor: UIColor(rgb: 0x132743))) { p in p.addEllipse(in: CGRect(x: 29, y: 41, width: 6, height: 6)) },
        .init(fill: nil) { p in p.move(to: .init(x: 50, y: 42)); p.addCurve(to: .init(x: 50, y: 62), control1: .init(x: 54, y: 50), control2: .init(x: 54, y: 56)) },
    ])
}
