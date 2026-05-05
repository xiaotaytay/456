import UIKit

class RadarOverlayView: UIView {

    var gameDataString: String = "" {
        didSet {
            setNeedsDisplay()
        }
    }
    var visible = true

    private var mapImage: UIImage?
    private var dragInitialCenter: CGPoint = .zero

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear
        loadMapImage()
        setupGestures()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func loadMapImage() {
        if let path = Bundle.main.path(forResource: "map", ofType: "png"),
           let img = UIImage(contentsOfFile: path) {
            mapImage = img
        }
    }

    private func setupGestures() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = superview else { return }
        let translation = gesture.translation(in: superview)

        switch gesture.state {
        case .began:
            dragInitialCenter = center
        case .changed:
            let newCenter = CGPoint(x: dragInitialCenter.x + translation.x, y: dragInitialCenter.y + translation.y)
            center = constrainCenter(newCenter, in: superview.bounds)
        case .ended, .cancelled:
            savePosition()
        default:
            break
        }
    }

    private func constrainCenter(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
        let halfW = frame.width / 2
        let halfH = frame.height / 2
        let x = max(halfW, min(bounds.width - halfW, point.x))
        let y = max(halfH, min(bounds.height - halfH, point.y))
        return CGPoint(x: x, y: y)
    }

    private func savePosition() {
        UserDefaults.standard.set(Double(frame.origin.x), forKey: "radar_overlay_x")
        UserDefaults.standard.set(Double(frame.origin.y), forKey: "radar_overlay_y")
    }

    override func draw(_ rect: CGRect) {
        super.draw(rect)
        guard visible else { return }

        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.clear(rect)
        ctx.interpolationQuality = .high

        let w = rect.width, h = rect.height
        let scaleX = w / RadarConstants.originalMapSize
        let scaleY = h / RadarConstants.originalMapSize

        let ms = MonsterSettings.shared
        let hs = HeroSettings.shared
        let renderer = RadarRenderer(
            scaleX: scaleX, scaleY: scaleY,
            canvasWidth: w, canvasHeight: h,
            heroOffsetX: CGFloat(hs.offsetX),
            heroOffsetY: CGFloat(hs.offsetY),
            heroScale: CGFloat(hs.scale),
            monsterOffsetX: CGFloat(ms.offsetX),
            monsterOffsetY: CGFloat(ms.offsetY),
            monsterScale: CGFloat(ms.scale)
        )

        let clipPath = UIBezierPath(roundedRect: rect, cornerRadius: 6)
        ctx.addPath(clipPath.cgPath)
        ctx.clip()

        if let mapImg = mapImage {
            ctx.interpolationQuality = .high
            mapImg.draw(in: CGRect(x: 0, y: 0, width: w, height: h))
        } else {
            ctx.setFillColor(UIColor(white: 0.05, alpha: 0.95).cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }

        if !gameDataString.isEmpty {
            let parts = gameDataString.components(separatedBy: "---")
            if parts.count >= 1, !parts[0].isEmpty {
                renderer.drawHeroes(ctx: ctx, heroPart: parts[0])
            }
            if parts.count >= 2, !parts[1].isEmpty {
                renderer.drawMonsters(ctx: ctx, monsterPart: parts[1])
            }
        }

        ctx.setStrokeColor(UIColor.white.withAlphaComponent(0.6).cgColor)
        ctx.setLineWidth(2)
        let borderPath = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 6)
        ctx.addPath(borderPath.cgPath)
        ctx.strokePath()
    }
}
