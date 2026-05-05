import UIKit

enum RadarConstants {
    static let originalMapSize: CGFloat = 340
    static let heroBaseSize: CGFloat = 40
    static let monsterBaseRadius: CGFloat = 5

    static let filteredMonsterX: Float = 108
    static let filteredMonsterY: Float = 104

    static let monsterIDDragon: String = "1660221"
    static let monsterIDTyrant: String = "166009"
    static let monsterIDOverlord: String = "166022"
    static let monsterIDGroup1: [String] = ["166009", "166018", "166012", "166022"]
    static let monsterIDGroup2: String = "166018"
    static let monsterIDGroup3: String = "166012"

    static let dragonCDThreshold: Int = 180
    static let tyrantCDThreshold: Int = 210
    static let overlordCDThreshold: Int = 210
    static let maxMonsterCD: Int = 240

    static let colorBlueBorder = UIColor(red: 0.15, green: 0.55, blue: 0.95, alpha: 1)
    static let colorRedBorder = UIColor.red
    static let colorBlueHP = UIColor(red: 0.09, green: 0.72, blue: 0.47, alpha: 1)
    static let colorRedHP = UIColor.red
    static let colorMonster = UIColor(red: 1, green: 0.72, blue: 0, alpha: 1)
    static let colorSkillGreen = UIColor(red: 0.19, green: 0.82, blue: 0.35, alpha: 1)
    static let colorSkillYellow = UIColor(red: 1, green: 0.72, blue: 0, alpha: 1)
    static let colorBlueLevelBg = UIColor(red: 0.29, green: 0.62, blue: 1, alpha: 0.9)
    static let colorRedLevelBg = UIColor(red: 1, green: 0.27, blue: 0.23, alpha: 0.9)
}

struct RadarRenderer {
    let scaleX: CGFloat
    let scaleY: CGFloat
    let canvasWidth: CGFloat
    let canvasHeight: CGFloat
    let uniformScale: CGFloat
    let heroOffsetX: CGFloat
    let heroOffsetY: CGFloat
    let heroScale: CGFloat
    let monsterOffsetX: CGFloat
    let monsterOffsetY: CGFloat
    let monsterScale: CGFloat

    init(scaleX: CGFloat, scaleY: CGFloat, canvasWidth: CGFloat, canvasHeight: CGFloat,
         heroOffsetX: CGFloat = 0, heroOffsetY: CGFloat = 0, heroScale: CGFloat = 1.0,
         monsterOffsetX: CGFloat = 0, monsterOffsetY: CGFloat = 0, monsterScale: CGFloat = 1.0) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.uniformScale = min(scaleX, scaleY)
        self.heroOffsetX = heroOffsetX
        self.heroOffsetY = heroOffsetY
        self.heroScale = heroScale
        self.monsterOffsetX = monsterOffsetX
        self.monsterOffsetY = monsterOffsetY
        self.monsterScale = monsterScale
    }

    func drawMapBackground(ctx: CGContext, mapImage: UIImage?) {
        if let mapImg = mapImage {
            ctx.interpolationQuality = .high
            mapImg.draw(in: CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        } else {
            ctx.setFillColor(UIColor(white: 0.05, alpha: 0.95).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
        }
    }

    func drawHeroes(ctx: CGContext, heroPart: String) {
        let heroStrings = heroPart.components(separatedBy: "==")
        for heroStr in heroStrings {
            guard let hero = HeroData.parse(heroStr) else { continue }
            drawSingleHero(ctx: ctx, hero: hero)
        }
    }

    private func drawSingleHero(ctx: CGContext, hero: HeroData) {
        let size = RadarConstants.heroBaseSize * scaleX * heroScale

        let pixelX = CGFloat(hero.x) * scaleX * heroScale + heroOffsetX
        let pixelY = CGFloat(hero.y) * scaleY * heroScale + heroOffsetY

        let drawX = pixelX - size / 2
        let drawY = pixelY - size / 2

        let borderColor = hero.team == 1 ? RadarConstants.colorBlueBorder : RadarConstants.colorRedBorder

        if let image = HeroImageCache.shared.getImage(String(hero.id)) {
            let imageRect = CGRect(x: drawX, y: drawY, width: size, height: size)
            ctx.saveGState()
            let radius = max(size, size) / 2 - 2
            ctx.addEllipse(in: CGRect(x: pixelX - radius, y: pixelY - radius, width: radius * 2, height: radius * 2))
            ctx.clip()
            image.draw(in: imageRect)
            ctx.restoreGState()
        } else {
            ctx.setFillColor(borderColor.withAlphaComponent(0.6).cgColor)
            ctx.addEllipse(in: CGRect(x: drawX + 1, y: drawY + 1, width: size - 2, height: size - 2))
            ctx.fillPath()
            HeroImageCache.shared.requestImage(String(hero.id)) { }
        }

        let borderRadius = max(size, size) / 2 - 1
        ctx.setStrokeColor(borderColor.cgColor)
        ctx.setLineWidth(4 * scaleX)
        ctx.addEllipse(in: CGRect(x: pixelX - borderRadius, y: pixelY - borderRadius, width: borderRadius * 2, height: borderRadius * 2))
        ctx.strokePath()

        let circleRadius = 8 * uniformScale
        let greenCircleX = pixelX + circleRadius - 2
        let greenCircleY = pixelY + size / 2 - circleRadius - 2
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.addEllipse(in: CGRect(x: greenCircleX - circleRadius - 1, y: greenCircleY - circleRadius - 1, width: (circleRadius + 1) * 2, height: (circleRadius + 1) * 2))
        ctx.fillPath()
        ctx.setFillColor(RadarConstants.colorSkillGreen.cgColor)
        ctx.addEllipse(in: CGRect(x: greenCircleX - circleRadius, y: greenCircleY - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
        ctx.fillPath()

        let yellowCircleX = pixelX - circleRadius + 2
        let yellowCircleY = pixelY + size / 2 - circleRadius - 2
        ctx.setFillColor(UIColor.white.cgColor)
        ctx.addEllipse(in: CGRect(x: yellowCircleX - circleRadius - 1, y: yellowCircleY - circleRadius - 1, width: (circleRadius + 1) * 2, height: (circleRadius + 1) * 2))
        ctx.fillPath()
        ctx.setFillColor(RadarConstants.colorSkillYellow.cgColor)
        ctx.addEllipse(in: CGRect(x: yellowCircleX - circleRadius, y: yellowCircleY - circleRadius, width: circleRadius * 2, height: circleRadius * 2))
        ctx.fillPath()

        if hero.level > 0 {
            drawLevel(ctx: ctx, pixelX: pixelX, pixelY: pixelY, size: size, level: hero.level, team: hero.team)
        }

        drawCDIndicators(ctx: ctx, greenCX: greenCircleX, greenCY: greenCircleY, yellowCX: yellowCircleX, yellowCY: yellowCircleY, hero: hero)

        drawHP(ctx: ctx, drawX: drawX, y: pixelY + size / 2, size: size, hp: hero.hp, team: hero.team)
    }

    private func drawLevel(ctx: CGContext, pixelX: CGFloat, pixelY: CGFloat, size: CGFloat, level: Int, team: Int) {
        let fontSize = max(10 * uniformScale, 9)
        let text = "Lv.\(level)" as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: UIColor.white]
        let textSize = text.size(withAttributes: attrs)
        let padding = 3 * uniformScale
        let bgW = textSize.width + padding * 2
        let bgH = fontSize + padding
        let levelX = pixelX - bgW / 2
        let levelY = pixelY - size / 2 - bgH - 2 * uniformScale
        let bgColor = team == 1 ? RadarConstants.colorBlueLevelBg : RadarConstants.colorRedLevelBg
        ctx.setFillColor(bgColor.cgColor)
        ctx.addRect(CGRect(x: levelX, y: levelY, width: bgW, height: bgH))
        ctx.fillPath()
        text.draw(at: CGPoint(x: levelX + padding, y: levelY + padding / 2), withAttributes: attrs)
    }

    private func drawCDIndicators(ctx: CGContext, greenCX: CGFloat, greenCY: CGFloat, yellowCX: CGFloat, yellowCY: CGFloat, hero: HeroData) {
        let fontSize = max(8 * uniformScale, 7)
        let ultText = hero.ultCD > 0 ? "\(Int(ceil(Float(hero.ultCD))))" : "✓"
        let skillText = hero.skillCD > 0 ? "\(Int(ceil(Float(hero.skillCD))))" : "✓"

        let ultAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: UIColor.white]
        let skillAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: UIColor.black]

        (ultText as NSString).draw(at: CGPoint(x: greenCX - fontSize / 2, y: greenCY - fontSize / 2), withAttributes: ultAttrs)
        (skillText as NSString).draw(at: CGPoint(x: yellowCX - fontSize / 2, y: yellowCY - fontSize / 2), withAttributes: skillAttrs)
    }

    private func drawHP(ctx: CGContext, drawX: CGFloat, y: CGFloat, size: CGFloat, hp: Int, team: Int) {
        let maxHPWidth = size
        let hpWidth = CGFloat(hp) / 100.0 * maxHPWidth

        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(5 * scaleX)
        ctx.move(to: CGPoint(x: drawX, y: y))
        ctx.addLine(to: CGPoint(x: drawX + maxHPWidth, y: y))
        ctx.strokePath()

        let hpColor = team == 1 ? RadarConstants.colorBlueHP : RadarConstants.colorRedHP
        ctx.setStrokeColor(hpColor.cgColor)
        ctx.move(to: CGPoint(x: drawX, y: y))
        ctx.addLine(to: CGPoint(x: drawX + hpWidth, y: y))
        ctx.strokePath()
    }

    func drawMonsters(ctx: CGContext, monsterPart: String) {
        let monsterStrings = monsterPart.components(separatedBy: "==")
        var monsters: [MonsterData] = []
        var cdMap: [String: Int] = [:]

        for str in monsterStrings {
            if let m = MonsterData.parse(str) {
                monsters.append(m)
                cdMap[m.id] = m.cd
            }
        }

        let cdDragon = cdMap[RadarConstants.monsterIDDragon]
        let cdTyrant = cdMap[RadarConstants.monsterIDTyrant]
        let cdOverlord = cdMap[RadarConstants.monsterIDOverlord]

        for m in monsters {
            if m.x == RadarConstants.filteredMonsterX && m.y == RadarConstants.filteredMonsterY { continue }

            var hideCountdown = false
            if let cd = cdDragon, cd > 0 && cd <= RadarConstants.dragonCDThreshold {
                if RadarConstants.monsterIDGroup1.contains(m.id) { hideCountdown = true }
            } else if let cd = cdTyrant, cd > 0 && cd <= RadarConstants.tyrantCDThreshold {
                if m.id == RadarConstants.monsterIDGroup2 { hideCountdown = true }
            }
            if let cd = cdOverlord, cd > 0 && cd <= RadarConstants.overlordCDThreshold {
                if m.id == RadarConstants.monsterIDGroup3 { hideCountdown = true }
            }

            let scaledX = CGFloat(m.x) * scaleX * monsterScale + monsterOffsetX
            let scaledY = CGFloat(m.y) * scaleY * monsterScale + monsterOffsetY

            if hideCountdown || m.isFullCD || m.cd == 0 {
                let radius = RadarConstants.monsterBaseRadius * uniformScale
                ctx.setFillColor(RadarConstants.colorMonster.cgColor)
                ctx.addEllipse(in: CGRect(x: scaledX - radius, y: scaledY - radius, width: radius * 2, height: radius * 2))
                ctx.fillPath()
                ctx.setStrokeColor(UIColor.white.cgColor)
                ctx.setLineWidth(1.5 * uniformScale)
                ctx.addEllipse(in: CGRect(x: scaledX - radius, y: scaledY - radius, width: radius * 2, height: radius * 2))
                ctx.strokePath()
            } else if m.cd > 0 && m.cd <= RadarConstants.maxMonsterCD {
                let fontSize = max(12 * uniformScale, 10)
                let cdText = "\(m.cd)" as NSString
                let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: fontSize), .foregroundColor: RadarConstants.colorMonster]
                let textSize = cdText.size(withAttributes: attrs)
                let padding = 4 * uniformScale
                let bgX = scaledX - textSize.width / 2 - padding
                let bgY = scaledY - fontSize / 2 - padding
                ctx.setFillColor(UIColor(white: 0, alpha: 0.7).cgColor)
                ctx.addRect(CGRect(x: bgX, y: bgY, width: textSize.width + padding * 2, height: fontSize + padding * 2))
                ctx.fillPath()
                cdText.draw(at: CGPoint(x: scaledX - textSize.width / 2, y: scaledY - fontSize / 2), withAttributes: attrs)
            }
        }
    }
}
