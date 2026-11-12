import AppKit
import simd
import QuartzCore

@main struct SnowballChecks {
    static let dt: Float = 1 / 60
    static let size = SIMD2<Float>(500, 300)

    static func require(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
        print("PASS: \(message)")
    }

    static func sprites(_ model: SnowSimulation) -> [Sprite] {
        let capacity = max(model.spriteCount, 1)
        let buffer = UnsafeMutablePointer<Sprite>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        let count = model.writeSprites(into: buffer, capacity: capacity)
        return Array(UnsafeBufferPointer(start: buffer, count: count))
    }

    static func ground(_ model: SnowSimulation) -> SnowLayer {
        Mirror(reflecting: model).children.first { $0.label == "ground" }!.value as! SnowLayer
    }

    static func model() -> SnowSimulation {
        let model = SnowSimulation(width: size.x, height: size.y, intensity: 0)
        model.tuning.meltingSpeed = 0
        model.tuning.physics = 0
        return model
    }

    static func roll(_ sim: SnowSimulation, from start: Int, to end: Int, y: Float = 5) {
        sim.snowballHeld = true
        for x in stride(from: start, through: end, by: 4) {
            _ = sim.step(dt: dt, cursor: SIMD2(Float(x), y))
        }
    }

    static func blastWidth(for diameter: Float) -> Float {
        let effect = SnowballInteraction()
        effect.adoptRoll(.init(area: 100, diameter: diameter, position: SIMD2(250, 50)), shift: .zero)
        let windows: [SIMD4<Float>] = [SIMD4(200, 0, 300, 100)]
        for _ in 0..<12 {
            _ = effect.step(dt: dt, held: false, cursor: nil, size: size, windows: windows, sensitivity: 1) {
                _, _, _, _ in (0, nil)
            }
        }
        let capacity = effect.spriteCount
        let buffer = UnsafeMutablePointer<Sprite>.allocate(capacity: capacity)
        defer { buffer.deallocate() }
        let count = effect.writeSprites(into: buffer, capacity: capacity)
        return (0..<count).map { abs(buffer[$0].position.x - 250) }.max() ?? 0
    }

    static func main() {
        let empty = model()
        roll(empty, from: 40, to: 180)
        empty.snowballHeld = false
        _ = empty.step(dt: dt, cursor: SIMD2(180, 5))
        require(sprites(empty).isEmpty && empty.isEmpty, "empty surface produces no ball and releases its temporary state")

        let snow = model()
        let g = ground(snow)
        for i in 0..<g.count { g.set(i, 5) }
        g.refreshTop()
        snow.snowballHeld = true
        _ = snow.step(dt: dt, cursor: SIMD2(60, 5))
        snow.snowballHeld = false
        _ = snow.step(dt: dt, cursor: SIMD2(60, 5))
        require(sprites(snow).isEmpty && g.heights.allSatisfy { $0 == 5 }, "modifier tap does not gather or launch snow")
        let initialArea = g.heights.reduce(0, +) * g.columnWidth
        roll(snow, from: 60, to: 100)
        let small = sprites(snow).last!
        roll(snow, from: 104, to: 400)
        let big = sprites(snow).last!
        require(small.lump > 0 && big.size > max(small.size, 48) && big.size <= 56,
                "ball grows past the old size limit and stays within the new cap")
        require(g.heights[g.clampedIndex(at: 75)] < 5 && g.heights[g.clampedIndex(at: 450)] == 5,
                "the path loses snow and untouched columns stay intact")
        require(abs(initialArea - g.heights.reduce(0, +) * g.columnWidth - 1600) < 0.1,
                "ball gains its full area from the snow it clears")
        roll(snow, from: 404, to: 424)
        let cappedArea = g.heights.reduce(0, +) * g.columnWidth
        require(abs(initialArea - cappedArea - 1600) < 0.1, "a full ball stops consuming snow")
        // The segment intersects this thin window in one frame without ending inside it.
        let window = SIMD4<Float>(274, 0, 276, 80)
        let hit = SnowballInteraction.firstImpact(from: SIMD2(245, 55), to: SIMD2(309, 55), radius: 6, size: size, windows: [window])
        require(hit != nil && abs(hit! - 23 / 64.0) < 0.001, "swept collision hits a thin window at the first contact")
        snow.snowballHeld = false
        _ = snow.step(dt: dt, cursor: SIMD2(428, 5))
        let flying = sprites(snow).last!
        require(flying.lump > 0 && flying.velocity.x > 20 && flying.position.x > 424,
                "release continues in the direction and speed of recent cursor motion")
        snow.windowFrames = [SIMD4(470, 0, 480, 80)]
        for _ in 0..<8 { _ = snow.step(dt: dt, cursor: SIMD2(-10000, -10000)) }
        require(sprites(snow).count > 1 && sprites(snow).allSatisfy { $0.lump == 0 }, "window impact replaces the ball with fragments")
        for _ in 0..<60 { _ = snow.step(dt: dt, cursor: SIMD2(-10000, -10000)) }
        require(sprites(snow).isEmpty && !snow.needsSnowballWindows, "fragments fade and the interaction stops updating")
        require(blastWidth(for: 54) > 2 * blastWidth(for: 7), "larger balls send fragments measurably farther")

        let ledgeSim = model()
        let edge = WindowSurface(id: 90, frame: CGRect(x: 30, y: 55, width: 240, height: 50),
                                 blockers: [], cover: [], cornerRadius: 4, cornerExponent: 2, isDock: false, sweeps: false)
        ledgeSim.updateWindows([edge], interval: 0.2)
        let layers = Mirror(reflecting: ledgeSim).children.first { $0.label == "layers" }!.value as! [SnowLayer]
        let ledge = layers[1]
        for i in 0..<ledge.count { ledge.set(i, 5) }
        ledge.refreshTop()
        roll(ledgeSim, from: 70, to: 150, y: 88)
        require(ledge.heights[ledge.clampedIndex(at: 100)] < 0.5 && ledge.heights[ledge.clampedIndex(at: 230)] > 4.9,
                "rolling below the lip clears a trail on the window while leaving distant snow in place")
        let held = sprites(ledgeSim).last!
        require(held.lump == SnowballInteraction.spriteLump && held.position == SIMD2(150, 88),
                "the round ball stays centered on the cursor below the ledge")
        let other = model()
        let transferred = ledgeSim.takeSnowballRoll()!
        other.adoptSnowballRoll(transferred, shift: SIMD2(-100, 0))
        require(sprites(ledgeSim).allSatisfy { $0.lump != SnowballInteraction.spriteLump }
                && sprites(other).first?.position == SIMD2(50, 88), "handoff shifts the held ball into the next display")
        other.snowballHeld = true
        for _ in 0..<12 { _ = other.step(dt: dt, cursor: SIMD2(50, 110)) }
        other.snowballHeld = false
        let before = sprites(other).last!.position
        _ = other.step(dt: dt, cursor: SIMD2(50, 110))
        let drop = sprites(other).last!
        require(abs(drop.velocity.x) < 0.001 && abs(drop.position.x - before.x) < 0.001,
                "holding still before release drops the ball without sideways motion")
        _ = other.step(dt: dt, cursor: SIMD2(50, 110))
        require(sprites(other).last!.position.y < drop.position.y, "a released ball falls")
        for _ in 0..<110 { _ = other.step(dt: dt, cursor: SIMD2(-10000, -10000)) }
        require(other.isEmpty && sprites(other).isEmpty, "a drop hitting the screen edge completes and releases all temporary state")
        ledgeSim.cancelSnowballs()
        require(!ledgeSim.snowballHeld && !ledgeSim.needsSnowballWindows, "cancellation discards gesture and animation state")
    }
}
