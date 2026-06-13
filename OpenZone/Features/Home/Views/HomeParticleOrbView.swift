import SwiftUI
import UIKit

struct HomeParticleOrbView: UIViewRepresentable {
    @Environment(\.sharedPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    func makeUIView(context: Context) -> ParticleOrbUIKitView {
        let view = ParticleOrbUIKitView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ uiView: ParticleOrbUIKitView, context: Context) {
        uiView.apply(
            colors: ParticleOrbColors(
                tint: UIColor(palette.textPrimary),
                accent: UIColor(palette.accentPrimary)
            ),
            shouldAnimate: reduceMotion == false && scenePhase == .active
        )
    }
}

final class ParticleOrbUIKitView: UIView {
    private let containerLayer = CALayer()
    private var activeColors: ParticleOrbColors?
    private var activePack: ParticleOrbAssetPack?
    private var orbLayers: [CALayer] = []
    private var outerOrbitDotLayers: [CALayer] = []
    private var sparkLayers: [CALayer] = []
    private var isAnimating = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isOpaque = false
        backgroundColor = .clear

        containerLayer.bounds = CGRect(origin: .zero, size: ParticleOrbMetrics.canvasSize)
        layer.addSublayer(containerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        containerLayer.position = CGPoint(x: bounds.midX, y: bounds.midY)

        let xScale = bounds.width / ParticleOrbMetrics.canvasSize.width
        let yScale = bounds.height / ParticleOrbMetrics.canvasSize.height
        let scale = min(xScale, yScale)
        containerLayer.transform = CATransform3DMakeScale(scale, scale, 1)
        CATransaction.commit()
    }

    fileprivate func apply(colors: ParticleOrbColors, shouldAnimate: Bool) {
        if activeColors.map({ colorsMatch($0, colors) }) != true {
            activeColors = colors
            installAssetPack(ParticleOrbAssetStore.pack(for: colors))
        }

        updateAnimationState(shouldAnimate)
    }

    private func colorsMatch(_ lhs: ParticleOrbColors, _ rhs: ParticleOrbColors) -> Bool {
        lhs.tint.isVisuallyEqual(to: rhs.tint) && lhs.accent.isVisuallyEqual(to: rhs.accent)
    }

    private func installAssetPack(_ pack: ParticleOrbAssetPack) {
        activePack = pack

        for layer in orbLayers {
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
        orbLayers.removeAll(keepingCapacity: true)

        for layer in outerOrbitDotLayers {
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
        outerOrbitDotLayers.removeAll(keepingCapacity: true)

        for layer in sparkLayers {
            layer.removeAllAnimations()
            layer.removeFromSuperlayer()
        }
        sparkLayers.removeAll(keepingCapacity: true)

        for descriptor in pack.layers {
            let layer = CALayer()
            layer.bounds = CGRect(origin: .zero, size: ParticleOrbMetrics.canvasSize)
            layer.position = ParticleOrbMetrics.center
            layer.contents = descriptor.image
            layer.contentsGravity = .resize
            layer.magnificationFilter = descriptor.crispEdges ? .nearest : .linear
            layer.minificationFilter = descriptor.crispEdges ? .nearest : .trilinear
            layer.opacity = descriptor.restOpacity
            layer.transform = CATransform3DMakeScale(descriptor.restScale, descriptor.restScale, 1)
            layer.shouldRasterize = false

            containerLayer.addSublayer(layer)
            orbLayers.append(layer)
        }

        for descriptor in pack.outerOrbitDots {
            let layer = CALayer()
            layer.bounds = CGRect(origin: .zero, size: descriptor.imageSize)
            layer.position = descriptor.position(progress: 0)
            layer.contents = descriptor.image
            layer.contentsGravity = .resizeAspect
            layer.magnificationFilter = .linear
            layer.minificationFilter = .trilinear
            layer.opacity = descriptor.restOpacity
            layer.transform = CATransform3DMakeScale(descriptor.restScale, descriptor.restScale, 1)

            containerLayer.addSublayer(layer)
            outerOrbitDotLayers.append(layer)
        }

        for descriptor in pack.sparks {
            let layer = CALayer()
            layer.bounds = CGRect(origin: .zero, size: descriptor.imageSize)
            layer.position = descriptor.position(progress: 0)
            layer.contents = descriptor.image
            layer.contentsGravity = .resizeAspect
            layer.magnificationFilter = .linear
            layer.minificationFilter = .trilinear
            layer.opacity = 0
            layer.transform = CATransform3DMakeScale(descriptor.restScale, descriptor.restScale, 1)

            containerLayer.addSublayer(layer)
            sparkLayers.append(layer)
        }

        updateAnimationState(isAnimating, force: true)
    }

    private func updateAnimationState(_ shouldAnimate: Bool, force: Bool = false) {
        guard let pack = activePack else { return }
        guard force || shouldAnimate != isAnimating else { return }

        isAnimating = shouldAnimate

        for (layer, descriptor) in zip(orbLayers, pack.layers) {
            layer.removeAllAnimations()
            layer.opacity = descriptor.restOpacity
            layer.position = ParticleOrbMetrics.center
            layer.transform = CATransform3DMakeScale(descriptor.restScale, descriptor.restScale, 1)

            guard shouldAnimate else { continue }

            let now = CACurrentMediaTime()

            if descriptor.driftRadius > 0 {
                let position = CAKeyframeAnimation(keyPath: "position")
                position.values = descriptor.driftPoints().map(NSValue.init(cgPoint:))
                position.duration = descriptor.driftDuration
                position.repeatCount = .infinity
                position.beginTime = now - descriptor.phaseOffset
                position.calculationMode = .paced
                position.isRemovedOnCompletion = false
                layer.add(position, forKey: "position")
            }

            if descriptor.rotationRange > 0 {
                let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
                rotation.fromValue = -descriptor.rotationRange
                rotation.toValue = descriptor.rotationRange
                rotation.duration = descriptor.rotationDuration
                rotation.autoreverses = true
                rotation.repeatCount = .infinity
                rotation.beginTime = now - descriptor.phaseOffset
                rotation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                rotation.isRemovedOnCompletion = false
                layer.add(rotation, forKey: "rotation")
            }

            if descriptor.scaleRange > 0 {
                let minScale = max(0.01, descriptor.restScale - descriptor.scaleRange)
                let maxScale = descriptor.restScale + descriptor.scaleRange
                let scale = CAKeyframeAnimation(keyPath: "transform.scale")
                scale.values = [descriptor.restScale, maxScale, descriptor.restScale, minScale, descriptor.restScale]
                scale.keyTimes = [0, 0.28, 0.55, 0.78, 1]
                scale.duration = descriptor.scaleDuration
                scale.repeatCount = .infinity
                scale.beginTime = now - descriptor.phaseOffset * 0.9
                scale.timingFunctions = [
                    CAMediaTimingFunction(name: .easeInEaseOut),
                    CAMediaTimingFunction(name: .easeInEaseOut),
                    CAMediaTimingFunction(name: .easeInEaseOut),
                    CAMediaTimingFunction(name: .easeInEaseOut)
                ]
                scale.isRemovedOnCompletion = false
                layer.add(scale, forKey: "scale")
            }

            if descriptor.opacityRange > 0 {
                let minOpacity = max(0.02, descriptor.restOpacity - descriptor.opacityRange)
                let maxOpacity = min(1, descriptor.restOpacity + descriptor.opacityRange)
                let opacity = CAKeyframeAnimation(keyPath: "opacity")
                opacity.values = [descriptor.restOpacity, maxOpacity, descriptor.restOpacity, minOpacity, descriptor.restOpacity]
                opacity.keyTimes = [0, 0.26, 0.56, 0.80, 1]
                opacity.duration = descriptor.opacityDuration
                opacity.repeatCount = .infinity
                opacity.beginTime = now - descriptor.phaseOffset * 1.1
                opacity.timingFunctions = [
                    CAMediaTimingFunction(name: .easeInEaseOut),
                    CAMediaTimingFunction(name: .easeInEaseOut),
                    CAMediaTimingFunction(name: .easeInEaseOut),
                    CAMediaTimingFunction(name: .easeInEaseOut)
                ]
                opacity.isRemovedOnCompletion = false
                layer.add(opacity, forKey: "opacity")
            }
        }

        for (layer, descriptor) in zip(outerOrbitDotLayers, pack.outerOrbitDots) {
            layer.removeAllAnimations()
            layer.position = descriptor.position(progress: 0)
            layer.opacity = descriptor.restOpacity
            layer.transform = CATransform3DMakeScale(descriptor.restScale, descriptor.restScale, 1)

            guard shouldAnimate else { continue }

            let now = CACurrentMediaTime()

            let position = CAKeyframeAnimation(keyPath: "position")
            position.values = descriptor.orbitPoints().map(NSValue.init(cgPoint:))
            position.duration = descriptor.orbitDuration
            position.repeatCount = .infinity
            position.beginTime = now - descriptor.phaseOffset
            position.calculationMode = .paced
            position.isRemovedOnCompletion = false
            layer.add(position, forKey: "position")

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            let lowOpacity = max(0.02, descriptor.restOpacity * 0.64)
            let highOpacity = min(0.30, descriptor.restOpacity * 1.22)
            opacity.values = [descriptor.restOpacity, highOpacity, descriptor.restOpacity, lowOpacity, descriptor.restOpacity]
            opacity.keyTimes = [0, 0.25, 0.52, 0.78, 1]
            opacity.duration = descriptor.opacityDuration
            opacity.repeatCount = .infinity
            opacity.beginTime = now - descriptor.phaseOffset * 0.8
            opacity.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
            opacity.isRemovedOnCompletion = false
            layer.add(opacity, forKey: "opacity")

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            scale.values = [
                descriptor.restScale,
                descriptor.restScale + descriptor.scaleRange,
                descriptor.restScale,
                max(0.01, descriptor.restScale - descriptor.scaleRange * 0.36),
                descriptor.restScale
            ]
            scale.keyTimes = [0, 0.28, 0.54, 0.80, 1]
            scale.duration = descriptor.scaleDuration
            scale.repeatCount = .infinity
            scale.beginTime = now - descriptor.phaseOffset * 0.55
            scale.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
            scale.isRemovedOnCompletion = false
            layer.add(scale, forKey: "scale")
        }

        for (layer, descriptor) in zip(sparkLayers, pack.sparks) {
            layer.removeAllAnimations()
            layer.position = descriptor.position(progress: 0)
            layer.opacity = shouldAnimate ? descriptor.restOpacity : 0
            layer.transform = CATransform3DMakeScale(descriptor.restScale, descriptor.restScale, 1)

            guard shouldAnimate else { continue }

            let now = CACurrentMediaTime()

            let position = CAKeyframeAnimation(keyPath: "position")
            position.values = descriptor.orbitPoints().map(NSValue.init(cgPoint:))
            position.duration = descriptor.orbitDuration
            position.repeatCount = .infinity
            position.beginTime = now - descriptor.phaseOffset
            position.calculationMode = .paced
            position.isRemovedOnCompletion = false
            layer.add(position, forKey: "position")

            let opacity = CAKeyframeAnimation(keyPath: "opacity")
            let lowOpacity = max(0.03, descriptor.restOpacity * 0.58)
            let highOpacity = min(0.42, descriptor.restOpacity * 1.18)
            opacity.values = [descriptor.restOpacity, highOpacity, descriptor.restOpacity * 0.82, lowOpacity, descriptor.restOpacity]
            opacity.keyTimes = [0, 0.24, 0.52, 0.78, 1]
            opacity.duration = descriptor.opacityDuration
            opacity.repeatCount = .infinity
            opacity.beginTime = now - descriptor.phaseOffset * 0.7
            opacity.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
            opacity.isRemovedOnCompletion = false
            layer.add(opacity, forKey: "opacity")

            let scale = CAKeyframeAnimation(keyPath: "transform.scale")
            let lowScale = max(0.01, descriptor.restScale - descriptor.scaleRange * 0.24)
            let highScale = descriptor.restScale + descriptor.scaleRange * 0.46
            scale.values = [
                descriptor.restScale,
                highScale,
                descriptor.restScale,
                lowScale,
                descriptor.restScale
            ]
            scale.keyTimes = [0, 0.27, 0.54, 0.78, 1]
            scale.duration = descriptor.scaleDuration
            scale.repeatCount = .infinity
            scale.beginTime = now - descriptor.phaseOffset
            scale.timingFunctions = [
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut),
                CAMediaTimingFunction(name: .easeInEaseOut)
            ]
            scale.isRemovedOnCompletion = false
            layer.add(scale, forKey: "scale")
        }
    }
}

private struct ParticleOrbColors {
    let tint: UIColor
    let accent: UIColor
}

private enum ParticleOrbMetrics {
    static let canvasSize = CGSize(width: 360, height: 240)
    static let center = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height * 0.5)
    static let outerField = CGSize(width: 324, height: 204)
    static let coreField = CGSize(width: 156, height: 146)
    static let renderScale = max(UIScreen.main.scale, 2)
    static let snapGrid: CGFloat = 3
    static let glyphRamp = Array("░▒▓█").map(String.init)
}

private struct ParticleOrbAssetPack {
    let layers: [ParticleOrbLayerDescriptor]
    let outerOrbitDots: [ParticleOrbOrbitDotDescriptor]
    let sparks: [ParticleOrbSparkDescriptor]
}

private struct ParticleOrbLayerDescriptor {
    let image: CGImage
    let restOpacity: Float
    let opacityRange: Float
    let opacityDuration: CFTimeInterval
    let restScale: CGFloat
    let scaleRange: CGFloat
    let scaleDuration: CFTimeInterval
    let rotationRange: CGFloat
    let rotationDuration: CFTimeInterval
    let phaseOffset: CFTimeInterval
    let crispEdges: Bool
    var driftRadius: CGFloat = 0
    var driftVerticalScale: CGFloat = 0.72
    var driftDuration: CFTimeInterval = 1

    func driftPoints() -> [CGPoint] {
        let stepCount = 36
        return (0...stepCount).map { step in
            let progress = CGFloat(step) / CGFloat(stepCount)
            let angle = progress * .pi * 2 + CGFloat(phaseOffset)
            return CGPoint(
                x: ParticleOrbMetrics.center.x + cos(angle) * driftRadius,
                y: ParticleOrbMetrics.center.y + sin(angle) * driftRadius * driftVerticalScale
            )
        }
    }
}

private struct ParticleOrbOrbitDotDescriptor {
    let image: CGImage
    let imageSize: CGSize
    let orbitRadius: CGFloat
    let verticalScale: CGFloat
    let angleOffset: CGFloat
    let radialPulse: CGFloat
    let orbitDuration: CFTimeInterval
    let opacityDuration: CFTimeInterval
    let scaleDuration: CFTimeInterval
    let phaseOffset: CFTimeInterval
    let restOpacity: Float
    let restScale: CGFloat
    let scaleRange: CGFloat

    func orbitPoints() -> [CGPoint] {
        let stepCount = 72
        return (0...stepCount).map { step in
            position(progress: CGFloat(step) / CGFloat(stepCount))
        }
    }

    func position(progress: CGFloat) -> CGPoint {
        let angle = angleOffset + progress * .pi * 2
        let radius = orbitRadius + sin(progress * .pi * 2 + angleOffset) * radialPulse
        return CGPoint(
            x: ParticleOrbMetrics.center.x + cos(angle) * radius,
            y: ParticleOrbMetrics.center.y + sin(angle) * radius * verticalScale
        )
    }
}

private struct ParticleOrbSparkDescriptor {
    let image: CGImage
    let imageSize: CGSize
    let orbitRadius: CGFloat
    let verticalScale: CGFloat
    let angleOffset: CGFloat
    let radialPulse: CGFloat
    let orbitDuration: CFTimeInterval
    let opacityDuration: CFTimeInterval
    let scaleDuration: CFTimeInterval
    let phaseOffset: CFTimeInterval
    let restOpacity: Float
    let restScale: CGFloat
    let scaleRange: CGFloat

    func orbitPoints() -> [CGPoint] {
        let stepCount = 48
        return (0...stepCount).map { step in
            position(progress: CGFloat(step) / CGFloat(stepCount))
        }
    }

    func position(progress: CGFloat) -> CGPoint {
        let angle = angleOffset + progress * .pi * 2
        let radius = orbitRadius + sin(progress * .pi * 2 + angleOffset * 0.6) * radialPulse
        return CGPoint(
            x: ParticleOrbMetrics.center.x + cos(angle) * radius,
            y: ParticleOrbMetrics.center.y + sin(angle) * radius * verticalScale
        )
    }
}

private enum ParticleOrbAssetStore {
    static func pack(for colors: ParticleOrbColors) -> ParticleOrbAssetPack {
        ParticleOrbAssetFactory.makePack(colors: colors)
    }
}

private extension UIColor {
    func isVisuallyEqual(to other: UIColor) -> Bool {
        let epsilon: CGFloat = 0.001
        
        // Use cgColor.components to avoid unsafe API warnings in Swift 6
        let componentsA = cgColor.components ?? [0, 0, 0, 0]
        let componentsB = other.cgColor.components ?? [0, 0, 0, 0]
        
        guard componentsA.count == 4, componentsB.count == 4 else {
            return self == other
        }
        
        return abs(componentsA[0] - componentsB[0]) < epsilon
            && abs(componentsA[1] - componentsB[1]) < epsilon
            && abs(componentsA[2] - componentsB[2]) < epsilon
            && abs(componentsA[3] - componentsB[3]) < epsilon
    }
}

private enum ParticleOrbAssetFactory {
    static func makePack(colors: ParticleOrbColors) -> ParticleOrbAssetPack {
        let tint = colors.tint

        let sparkSeeds = ParticleOrbLayoutFactory.makeSparkSeeds(seedOffset: 11200, count: 28)
        let outerOrbitDotImage = ParticleOrbRenderer.renderOrbitDot(tint: tint)
        let outerOrbitDotSeeds = ParticleOrbLayoutFactory.makeOuterOrbitDotSeeds(seedOffset: 12800, count: 42)

        return ParticleOrbAssetPack(
            layers: [
                ParticleOrbLayerDescriptor(
                    image: ParticleOrbRenderer.renderDots(
                        tint: tint,
                        dots: ParticleOrbLayoutFactory.makeOuterDots(seedOffset: 0, count: 138, radiusBias: 0.72)
                    ),
                    restOpacity: 0.36,
                    opacityRange: 0.05,
                    opacityDuration: 6.8,
                    restScale: 1,
                    scaleRange: 0.018,
                    scaleDuration: 8.4,
                    rotationRange: 0.09,
                    rotationDuration: 21,
                    phaseOffset: 0,
                    crispEdges: false,
                    driftRadius: 5,
                    driftVerticalScale: 0.72,
                    driftDuration: 16
                ),
                ParticleOrbLayerDescriptor(
                    image: ParticleOrbRenderer.renderDots(
                        tint: tint,
                        dots: ParticleOrbLayoutFactory.makeOuterDots(seedOffset: 1200, count: 126, radiusBias: 0.66)
                    ),
                    restOpacity: 0.28,
                    opacityRange: 0.05,
                    opacityDuration: 7.6,
                    restScale: 0.98,
                    scaleRange: 0.022,
                    scaleDuration: 9.2,
                    rotationRange: 0.07,
                    rotationDuration: 17.5,
                    phaseOffset: 1.9,
                    crispEdges: false,
                    driftRadius: 7,
                    driftVerticalScale: 0.56,
                    driftDuration: 19
                ),
                ParticleOrbLayerDescriptor(
                    image: ParticleOrbRenderer.renderDots(
                        tint: tint,
                        dots: ParticleOrbLayoutFactory.makePulseDots(seedOffset: 1800, count: 86)
                    ),
                    restOpacity: 0.20,
                    opacityRange: 0.10,
                    opacityDuration: 5.2,
                    restScale: 0.78,
                    scaleRange: 0.12,
                    scaleDuration: 5.8,
                    rotationRange: 0.04,
                    rotationDuration: 13,
                    phaseOffset: 0.4,
                    crispEdges: false,
                    driftRadius: 2,
                    driftVerticalScale: 0.7,
                    driftDuration: 11
                ),
                ParticleOrbLayerDescriptor(
                    image: ParticleOrbRenderer.renderBlocks(
                        tint: colors.accent,
                        blocks: ParticleOrbLayoutFactory.makeCoreBlocks(seedOffset: 2400, count: 236, prominence: 0.96)
                    ),
                    restOpacity: 0.78,
                    opacityRange: 0.10,
                    opacityDuration: 5.8,
                    restScale: 1,
                    scaleRange: 0.028,
                    scaleDuration: 6.6,
                    rotationRange: 0.10,
                    rotationDuration: 12,
                    phaseOffset: 0.8,
                    crispEdges: true,
                    driftRadius: 4,
                    driftVerticalScale: 0.74,
                    driftDuration: 8.5
                ),
                ParticleOrbLayerDescriptor(
                    image: ParticleOrbRenderer.renderBlocks(
                        tint: colors.accent,
                        blocks: ParticleOrbLayoutFactory.makeCoreBlocks(seedOffset: 4800, count: 220, prominence: 0.78)
                    ),
                    restOpacity: 0.52,
                    opacityRange: 0.09,
                    opacityDuration: 6.4,
                    restScale: 1.02,
                    scaleRange: 0.024,
                    scaleDuration: 6.1,
                    rotationRange: 0.14,
                    rotationDuration: 9.8,
                    phaseOffset: 2.2,
                    crispEdges: true,
                    driftRadius: 5,
                    driftVerticalScale: 0.68,
                    driftDuration: 7.8
                ),
                ParticleOrbLayerDescriptor(
                    image: ParticleOrbRenderer.renderBlocks(
                        tint: colors.accent,
                        blocks: ParticleOrbLayoutFactory.makeCoreBlocks(seedOffset: 7200, count: 158, prominence: 0.58)
                    ),
                    restOpacity: 0.30,
                    opacityRange: 0.06,
                    opacityDuration: 6.4,
                    restScale: 1.04,
                    scaleRange: 0.018,
                    scaleDuration: 6.1,
                    rotationRange: 0.18,
                    rotationDuration: 7.4,
                    phaseOffset: 3.1,
                    crispEdges: true,
                    driftRadius: 6,
                    driftVerticalScale: 0.64,
                    driftDuration: 6.9
                ),
                ParticleOrbLayerDescriptor(
                    image: ParticleOrbRenderer.renderDots(
                        tint: tint,
                        dots: ParticleOrbLayoutFactory.makeOrbDust(seedOffset: 9600, count: 132)
                    ),
                    restOpacity: 0.30,
                    opacityRange: 0.08,
                    opacityDuration: 4.4,
                    restScale: 1.01,
                    scaleRange: 0.032,
                    scaleDuration: 5.6,
                    rotationRange: 0.12,
                    rotationDuration: 10.6,
                    phaseOffset: 1.5,
                    crispEdges: false,
                    driftRadius: 8,
                    driftVerticalScale: 0.62,
                    driftDuration: 12.4
                )
            ],
            outerOrbitDots: outerOrbitDotSeeds.map { seed in
                ParticleOrbOrbitDotDescriptor(
                    image: outerOrbitDotImage,
                    imageSize: CGSize(width: 10, height: 10),
                    orbitRadius: seed.orbitRadius,
                    verticalScale: seed.verticalScale,
                    angleOffset: seed.angleOffset,
                    radialPulse: seed.radialPulse,
                    orbitDuration: seed.orbitDuration,
                    opacityDuration: seed.opacityDuration,
                    scaleDuration: seed.scaleDuration,
                    phaseOffset: seed.phaseOffset,
                    restOpacity: seed.restOpacity,
                    restScale: seed.restScale,
                    scaleRange: seed.scaleRange
                )
            },
            sparks: sparkSeeds.map { seed in
                ParticleOrbSparkDescriptor(
                    image: ParticleOrbRenderer.renderSpark(tint: tint, glyph: seed.glyph, pointSize: seed.pointSize),
                    imageSize: CGSize(width: 18, height: 18),
                    orbitRadius: seed.orbitRadius,
                    verticalScale: seed.verticalScale,
                    angleOffset: seed.angleOffset,
                    radialPulse: seed.radialPulse,
                    orbitDuration: seed.orbitDuration,
                    opacityDuration: seed.opacityDuration,
                    scaleDuration: seed.scaleDuration,
                    phaseOffset: seed.phaseOffset,
                    restOpacity: seed.restOpacity,
                    restScale: seed.restScale,
                    scaleRange: seed.scaleRange
                )
            }
        )
    }
}

private enum ParticleOrbRenderer {
    static func renderDots(tint: UIColor, dots: [ParticleDot]) -> CGImage {
        renderImage { context in
            for dot in dots {
                context.setFillColor(tint.withAlphaComponent(dot.opacity).cgColor)
                let rect = CGRect(
                    x: dot.point.x - dot.size * 0.5,
                    y: dot.point.y - dot.size * 0.5,
                    width: dot.size,
                    height: dot.size
                )
                context.fillEllipse(in: rect)
            }
        }
    }

    static func renderBlocks(tint: UIColor, blocks: [ParticleBlock]) -> CGImage {
        renderImage { _ in
            for block in blocks {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.monospacedSystemFont(ofSize: block.size, weight: .regular),
                    .foregroundColor: tint.withAlphaComponent(block.opacity)
                ]
                let string = NSAttributedString(string: block.glyph, attributes: attributes)
                let stringSize = string.size()
                string.draw(
                    at: CGPoint(
                        x: block.point.x - stringSize.width * 0.5,
                        y: block.point.y - stringSize.height * 0.5
                    )
                )
            }
        }
    }

    static func renderSpark(tint: UIColor, glyph: String, pointSize: CGFloat) -> CGImage {
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 18, height: 18),
            format: rendererFormat()
        )
        let image = renderer.image { _ in
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: pointSize, weight: .regular),
                .foregroundColor: tint
            ]
            let string = NSAttributedString(string: glyph, attributes: attributes)
            let size = string.size()
            string.draw(
                at: CGPoint(
                    x: (18 - size.width) * 0.5,
                    y: (18 - size.height) * 0.5
                )
            )
        }

        guard let cgImage = image.cgImage else {
            preconditionFailure("Expected raster spark image")
        }

        return cgImage
    }

    static func renderOrbitDot(tint: UIColor) -> CGImage {
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: 10, height: 10),
            format: rendererFormat()
        )
        let image = renderer.image { renderContext in
            let context = renderContext.cgContext
            context.setFillColor(tint.withAlphaComponent(0.82).cgColor)
            context.fillEllipse(in: CGRect(x: 2, y: 2, width: 6, height: 6))
            context.setFillColor(tint.withAlphaComponent(0.18).cgColor)
            context.fillEllipse(in: CGRect(x: 0.6, y: 0.6, width: 8.8, height: 8.8))
        }

        guard let cgImage = image.cgImage else {
            preconditionFailure("Expected raster outer dot image")
        }

        return cgImage
    }

    static func renderImage(_ draw: (CGContext) -> Void) -> CGImage {
        let renderer = UIGraphicsImageRenderer(
            size: ParticleOrbMetrics.canvasSize,
            format: rendererFormat()
        )
        let image = renderer.image { renderContext in
            let context = renderContext.cgContext
            context.interpolationQuality = .high
            draw(context)
        }

        guard let cgImage = image.cgImage else {
            preconditionFailure("Expected raster orb image")
        }

        return cgImage
    }

    static func rendererFormat() -> UIGraphicsImageRendererFormat {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = false
        format.scale = ParticleOrbMetrics.renderScale
        return format
    }
}

private enum ParticleOrbLayoutFactory {
    static func makeOuterDots(seedOffset: Int, count: Int, radiusBias: Double) -> [ParticleDot] {
        var dots: [ParticleDot] = []
        dots.reserveCapacity(count)

        for index in 0..<count {
            let seed = Double(seedOffset + index)
            let orbit = 0.28 + pow(ParticleOrbMath.noise(seed, 3), 0.82) * radiusBias
            let angle = ParticleOrbMath.noise(seed, 11) * .pi * 2
            let jitterX = (ParticleOrbMath.noise(seed, 29) - 0.5) * 14
            let jitterY = (ParticleOrbMath.noise(seed, 37) - 0.5) * 11
            let point = CGPoint(
                x: ParticleOrbMetrics.center.x + cos(angle) * ParticleOrbMetrics.outerField.width * CGFloat(orbit) * 0.5 + jitterX,
                y: ParticleOrbMetrics.center.y + sin(angle) * ParticleOrbMetrics.outerField.height * CGFloat(orbit) * 0.5 + jitterY
            )
            let size = CGFloat(1.2 + ParticleOrbMath.noise(seed, 47) * 2.4)
            let opacity = CGFloat(0.16 + ParticleOrbMath.noise(seed, 59) * 0.28)
            dots.append(
                ParticleDot(
                    point: point,
                    size: size,
                    opacity: opacity
                )
            )
        }

        return dots
    }

    static func makeOrbDust(seedOffset: Int, count: Int) -> [ParticleDot] {
        var dots: [ParticleDot] = []
        dots.reserveCapacity(count)

        for index in 0..<count {
            let seed = Double(seedOffset + index)
            let angle = ParticleOrbMath.noise(seed, 5) * .pi * 2
            let radial = 0.18 + pow(ParticleOrbMath.noise(seed, 13), 0.58) * 0.50
            let point = CGPoint(
                x: ParticleOrbMetrics.center.x + cos(angle) * ParticleOrbMetrics.outerField.width * CGFloat(radial) * 0.38,
                y: ParticleOrbMetrics.center.y + sin(angle) * ParticleOrbMetrics.outerField.height * CGFloat(radial) * 0.34
            )
            let size = CGFloat(1.1 + ParticleOrbMath.noise(seed, 23) * 2.0)
            let opacity = CGFloat(0.10 + ParticleOrbMath.noise(seed, 31) * 0.18)

            dots.append(
                ParticleDot(
                    point: point,
                    size: size,
                    opacity: opacity
                )
            )
        }

        return dots
    }

    static func makePulseDots(seedOffset: Int, count: Int) -> [ParticleDot] {
        var dots: [ParticleDot] = []
        dots.reserveCapacity(count)

        for index in 0..<count {
            let seed = Double(seedOffset + index)
            let angle = Double(index) / Double(count) * .pi * 2 + (ParticleOrbMath.noise(seed, 5) - 0.5) * 0.22
            let radius = CGFloat(0.38 + ParticleOrbMath.noise(seed, 13) * 0.16)
            let point = CGPoint(
                x: ParticleOrbMetrics.center.x + cos(angle) * ParticleOrbMetrics.coreField.width * radius,
                y: ParticleOrbMetrics.center.y + sin(angle) * ParticleOrbMetrics.coreField.height * radius * 0.70
            )
            let size = CGFloat(1.0 + ParticleOrbMath.noise(seed, 19) * 2.1)
            let opacity = CGFloat(0.08 + ParticleOrbMath.noise(seed, 31) * 0.22)

            dots.append(ParticleDot(point: point, size: size, opacity: opacity))
        }

        return dots
    }

    static func makeSparkSeeds(seedOffset: Int, count: Int) -> [ParticleSparkSeed] {
        var seeds: [ParticleSparkSeed] = []
        seeds.reserveCapacity(count)

        for index in 0..<count {
            let seed = Double(seedOffset + index)
            let energy = ParticleOrbMath.noise(seed, 7)
            let glyphIndex = min(
                ParticleOrbMetrics.glyphRamp.count - 1,
                max(0, Int((energy * Double(ParticleOrbMetrics.glyphRamp.count)).rounded()) - 1)
            )
            let angleOffset = CGFloat(ParticleOrbMath.noise(seed, 13) * .pi * 2)
            let orbitRadius = CGFloat(34 + ParticleOrbMath.noise(seed, 17) * 76)
            let pointSize = CGFloat(5.2 + ParticleOrbMath.noise(seed, 23) * 4.8)
            let opacity = Float(0.08 + ParticleOrbMath.noise(seed, 29) * 0.18)

            seeds.append(
                ParticleSparkSeed(
                    glyph: ParticleOrbMetrics.glyphRamp[glyphIndex],
                    pointSize: pointSize,
                    orbitRadius: orbitRadius,
                    verticalScale: CGFloat(0.58 + ParticleOrbMath.noise(seed, 31) * 0.26),
                    angleOffset: angleOffset,
                    radialPulse: CGFloat(2 + ParticleOrbMath.noise(seed, 37) * 5),
                    orbitDuration: CFTimeInterval(8.5 + ParticleOrbMath.noise(seed, 41) * 10.0),
                    opacityDuration: CFTimeInterval(5.5 + ParticleOrbMath.noise(seed, 43) * 5.0),
                    scaleDuration: CFTimeInterval(6.0 + ParticleOrbMath.noise(seed, 47) * 5.0),
                    phaseOffset: CFTimeInterval(ParticleOrbMath.noise(seed, 53) * 9.0),
                    restOpacity: opacity,
                    restScale: CGFloat(0.74 + ParticleOrbMath.noise(seed, 59) * 0.34),
                    scaleRange: CGFloat(0.06 + ParticleOrbMath.noise(seed, 61) * 0.10)
                )
            )
        }

        return seeds
    }

    static func makeOuterOrbitDotSeeds(seedOffset: Int, count: Int) -> [ParticleOrbitDotSeed] {
        var seeds: [ParticleOrbitDotSeed] = []
        seeds.reserveCapacity(count)

        for index in 0..<count {
            let seed = Double(seedOffset + index)
            let angleOffset = CGFloat(Double(index) / Double(count) * .pi * 2)
                + CGFloat((ParticleOrbMath.noise(seed, 13) - 0.5) * 0.18)
            let ring = ParticleOrbMath.noise(seed, 17)
            let orbitRadius = CGFloat(94 + ring * 72)
            let opacity = Float(0.07 + ParticleOrbMath.noise(seed, 29) * 0.15)

            seeds.append(
                ParticleOrbitDotSeed(
                    orbitRadius: orbitRadius,
                    verticalScale: CGFloat(0.56 + ParticleOrbMath.noise(seed, 31) * 0.22),
                    angleOffset: angleOffset,
                    radialPulse: CGFloat(1.4 + ParticleOrbMath.noise(seed, 37) * 4.6),
                    orbitDuration: CFTimeInterval(17.0 + ParticleOrbMath.noise(seed, 41) * 14.0),
                    opacityDuration: CFTimeInterval(7.5 + ParticleOrbMath.noise(seed, 43) * 7.0),
                    scaleDuration: CFTimeInterval(8.0 + ParticleOrbMath.noise(seed, 47) * 6.5),
                    phaseOffset: CFTimeInterval(ParticleOrbMath.noise(seed, 53) * 13.0),
                    restOpacity: opacity,
                    restScale: CGFloat(0.34 + ParticleOrbMath.noise(seed, 59) * 0.56),
                    scaleRange: CGFloat(0.035 + ParticleOrbMath.noise(seed, 61) * 0.07)
                )
            )
        }

        return seeds
    }

    static func makeCoreBlocks(seedOffset: Int, count: Int, prominence: Double) -> [ParticleBlock] {
        var blocks: [ParticleBlock] = []
        blocks.reserveCapacity(count)

        let maxAttempts = count * 12
        var attempts = 0

        while blocks.count < count && attempts < maxAttempts {
            let seed = Double(seedOffset + attempts)
            let x = ParticleOrbMath.noise(seed, 3) * 2 - 1
            let y = ParticleOrbMath.noise(seed, 9) * 2 - 1
            let density = coreDensity(x: x, y: y, seed: seed) * prominence

            if ParticleOrbMath.noise(seed, 15) < density {
                let snappedX = snap(
                    ParticleOrbMetrics.center.x + CGFloat(x) * ParticleOrbMetrics.coreField.width * 0.5
                )
                let snappedY = snap(
                    ParticleOrbMetrics.center.y + CGFloat(y) * ParticleOrbMetrics.coreField.height * 0.5
                )
                let energy = min(1, max(0, density + ParticleOrbMath.noise(seed, 25) * 0.12))
                let size = CGFloat(4.1 + energy * 5.8 + ParticleOrbMath.noise(seed, 21) * 1.1)
                let glyphIndex = min(
                    ParticleOrbMetrics.glyphRamp.count - 1,
                    max(0, Int((energy * Double(ParticleOrbMetrics.glyphRamp.count)).rounded()) - 1)
                )
                let opacity = CGFloat(min(1, 0.18 + energy * 0.82 + ParticleOrbMath.noise(seed, 33) * 0.08))

                blocks.append(
                    ParticleBlock(
                        point: CGPoint(x: snappedX, y: snappedY),
                        glyph: ParticleOrbMetrics.glyphRamp[glyphIndex],
                        size: size,
                        opacity: opacity
                    )
                )
            }

            attempts += 1
        }

        return blocks
    }

    static func coreDensity(x: Double, y: Double, seed: Double) -> Double {
        let radius = sqrt(x * x + y * y)
        let angle = atan2(y, x)
        let shell = max(0, 1 - pow(radius / 1.05, 2)) * 0.36
        let ring = exp(-pow((radius - 0.56) / 0.24, 2)) * 0.34
        let centerMass = ParticleOrbMath.gaussian2D(x: x + 0.03, y: y + 0.02, sigmaX: 0.34, sigmaY: 0.30) * 0.38
        let upperLeftMass = ParticleOrbMath.gaussian2D(x: x + 0.24, y: y + 0.15, sigmaX: 0.28, sigmaY: 0.18) * 0.28
        let lowerRightMass = ParticleOrbMath.gaussian2D(x: x - 0.22, y: y - 0.20, sigmaX: 0.22, sigmaY: 0.20) * 0.24
        let spiral = (0.5 + 0.5 * sin(angle * 3.2 + radius * 8.4)) * 0.16
        let centerCut = ParticleOrbMath.gaussian2D(x: x - 0.02, y: y - 0.02, sigmaX: 0.18, sigmaY: 0.16) * 0.20
        let bite = ParticleOrbMath.gaussian2D(x: x + 0.34, y: y - 0.23, sigmaX: 0.18, sigmaY: 0.14) * 0.18
        let noise = (ParticleOrbMath.noise(seed, 41) - 0.5) * 0.20

        return min(1, max(0, shell + ring + centerMass + upperLeftMass + lowerRightMass + spiral - centerCut - bite + noise))
    }

    static func snap(_ value: CGFloat) -> CGFloat {
        (value / ParticleOrbMetrics.snapGrid).rounded() * ParticleOrbMetrics.snapGrid
    }
}

private struct ParticleDot {
    let point: CGPoint
    let size: CGFloat
    let opacity: CGFloat
}

private struct ParticleBlock {
    let point: CGPoint
    let glyph: String
    let size: CGFloat
    let opacity: CGFloat
}

private struct ParticleOrbitDotSeed {
    let orbitRadius: CGFloat
    let verticalScale: CGFloat
    let angleOffset: CGFloat
    let radialPulse: CGFloat
    let orbitDuration: CFTimeInterval
    let opacityDuration: CFTimeInterval
    let scaleDuration: CFTimeInterval
    let phaseOffset: CFTimeInterval
    let restOpacity: Float
    let restScale: CGFloat
    let scaleRange: CGFloat
}

private struct ParticleSparkSeed {
    let glyph: String
    let pointSize: CGFloat
    let orbitRadius: CGFloat
    let verticalScale: CGFloat
    let angleOffset: CGFloat
    let radialPulse: CGFloat
    let orbitDuration: CFTimeInterval
    let opacityDuration: CFTimeInterval
    let scaleDuration: CFTimeInterval
    let phaseOffset: CFTimeInterval
    let restOpacity: Float
    let restScale: CGFloat
    let scaleRange: CGFloat
}

private enum ParticleOrbMath {
    nonisolated static func noise(_ value: Double, _ seed: Double) -> Double {
        let mixed = sin(value * 12.9898 + seed * 78.233) * 43758.5453
        return mixed - floor(mixed)
    }

    nonisolated static func gaussian2D(
        x: Double,
        y: Double,
        sigmaX: Double,
        sigmaY: Double
    ) -> Double {
        exp(-0.5 * (pow(x / sigmaX, 2) + pow(y / sigmaY, 2)))
    }
}

#Preview {
    ZStack {
        SharedOpenZonePalette.resolve(.light).surfaceBase.ignoresSafeArea()
        HomeParticleOrbView()
            .frame(height: 240)
            .padding(.horizontal, 28)
            .environment(\.sharedPalette, SharedOpenZonePalette.resolve(.light))
    }
}
