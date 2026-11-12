import simd

/// Allocated only while rolling a ball or while its throw and fragments are on screen.
final class SnowballInteraction {
    private static let maximumArea: Float = 1_600
    private static let maximumDiameter: Float = 56
    private static let minimumArea: Float = 6
    private static let history: Double = 0.13
    private static let maxThrows = 4
    private static let maxFragments = 72
    /// The shader reserves values above 1 for round snowballs. Loose clumps use seeds up to 1.
    static let spriteLump: Float = 1.58

    struct Roll {
        var area: Float = 0
        var diameter: Float = 0
        /// The surface contact anchors the throw above any window used to collect snow.
        var position: SIMD2<Float> = .zero
        var angle: Float = 0
        fileprivate var cursorPosition: SIMD2<Float>?
        fileprivate var samples: [(time: Double, point: SIMD2<Float>)] = []
    }

    private struct Throw {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        let diameter: Float
        var angle: Float
        var age: Float = 0
    }

    private struct Fragment {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        let size: Float
        let life: Float
        var age: Float = 0
    }

    private(set) var roll: Roll?
    private var throwsInFlight: [Throw] = []
    private var fragments: [Fragment] = []
    private var time: Double = 0

    var empty: Bool { roll == nil && !airborne }
    private var airborne: Bool { !throwsInFlight.isEmpty || !fragments.isEmpty }
    var needsCollisionGeometry: Bool {
        !throwsInFlight.isEmpty || roll.map { $0.area >= Self.minimumArea } == true
    }
    var spriteCount: Int {
        (roll.map { $0.area >= Self.minimumArea } == true ? 1 : 0) + throwsInFlight.count + fragments.count
    }

    func takeRoll() -> Roll? {
        defer { roll = nil }
        return roll
    }

    func adoptRoll(_ transferred: Roll, shift: SIMD2<Float>) {
        var transferred = transferred
        transferred.position += shift
        if let cursor = transferred.cursorPosition { transferred.cursorPosition = cursor + shift }
        transferred.samples.removeAll(keepingCapacity: true)
        roll = transferred
    }

    /// `collect` returns the area removed and the height of the surface supporting the ball.
    func step(dt: Float, held: Bool, cursor: SIMD2<Float>?, size: SIMD2<Float>, windows: [SIMD4<Float>],
              sensitivity: Float, collect: (SIMD2<Float>, Float, Float, Float) -> (area: Float, surface: Float?)) -> Bool {
        let wasVisible = spriteCount > 0
        time += Double(dt)
        if held {
            var draft = takeRoll() ?? Roll()
            if let cursor {
                draft.cursorPosition = cursor
                if let previous = draft.samples.last?.point {
                    let travel = simd_length(cursor - previous)
                    if travel > 0.05 && travel <= 400 {
                        let steps = max(1, Int((travel / 4).rounded(.up)))
                        let stride = (cursor - previous) / Float(steps)
                        let distance = travel / Float(steps)
                        draft.position = cursor
                        for i in 1...steps {
                            let remaining = max(0, Self.maximumArea - draft.area)
                            if remaining <= 0.001 && i != steps { continue }
                            let point = previous + stride * Float(i)
                            let reach = max(10, 0.44 * draft.diameter)
                            let contact = collect(point, distance * sensitivity, remaining, reach)
                            draft.area += contact.area
                            if i == steps, let surface = contact.surface { draft.position.y = surface }
                        }
                    } else if travel > 400 {
                        draft.samples.removeAll(keepingCapacity: true)
                        draft.position = cursor
                    }
                    if travel <= 400 {
                        draft.angle = (draft.angle - (cursor.x - previous.x) / max(4, draft.diameter * 0.65))
                            .truncatingRemainder(dividingBy: 2 * .pi)
                    }
                } else {
                    draft.position = cursor
                }
                sample(cursor, for: &draft)
            } else if let last = draft.samples.last?.point {
                // Outside every display or behind a system panel, leave the draft at its last position.
                sample(last, for: &draft)
            }
            let diameter = min(Self.maximumDiameter, 1.4 * draft.area.squareRoot())
            draft.diameter += (diameter - draft.diameter) * (1 - exp(-dt / 0.055))
            roll = draft
        } else if var draft = takeRoll(), draft.area >= Self.minimumArea {
            if let last = draft.samples.last?.point {
                let current = cursor ?? last
                sample(simd_length_squared(current - last) <= 400 * 400 ? current : last, for: &draft)
            }
            let velocity = launchVelocity(draft)
            let diameter = max(3, draft.diameter)
            let radius = diameter * 0.56
            let center = draft.position + SIMD2(0, radius + 4)
            let position = simd_clamp(center, SIMD2(repeating: radius), size - SIMD2(repeating: radius))
            if throwsInFlight.count == Self.maxThrows { throwsInFlight.removeFirst() }
            throwsInFlight.append(Throw(position: position, velocity: velocity, diameter: diameter, angle: draft.angle))
        }

        for i in throwsInFlight.indices.reversed() {
            var ball = throwsInFlight[i]
            let start = ball.position
            let gravity = SIMD2<Float>(0, -320)
            let end = start + (ball.velocity + gravity * (dt * 0.5)) * dt
            ball.velocity = (ball.velocity + gravity * dt) * exp(-dt * 0.18)
            ball.angle += ball.velocity.x / max(6, ball.diameter) * dt * -0.8
            ball.age += dt
            let radius = ball.diameter * 0.56
            if let contact = Self.firstImpact(from: start, to: end, radius: radius, size: size, windows: windows) {
                shatter(at: start + (end - start) * contact, velocity: ball.velocity, diameter: ball.diameter)
                throwsInFlight.remove(at: i)
            } else if ball.age > 5 {
                throwsInFlight.remove(at: i)
            } else {
                ball.position = end
                throwsInFlight[i] = ball
            }
        }
        let fragmentDrag = fragments.isEmpty ? 1 : exp(-3 * dt)
        for i in fragments.indices.reversed() {
            fragments[i].age += dt
            if fragments[i].age >= fragments[i].life {
                fragments.remove(at: i)
            } else {
                fragments[i].velocity *= fragmentDrag
                fragments[i].velocity.y -= 105 * dt
                fragments[i].position += fragments[i].velocity * dt
            }
        }
        return wasVisible || spriteCount > 0
    }

    private func sample(_ cursor: SIMD2<Float>, for draft: inout Roll) {
        draft.samples.append((time, cursor))
        while draft.samples.count > 2 && draft.samples[1].time <= time - Self.history {
            draft.samples.removeFirst()
        }
    }

    private func launchVelocity(_ draft: Roll) -> SIMD2<Float> {
        guard let first = draft.samples.first, let last = draft.samples.last, draft.samples.count > 1 else { return .zero }
        let startTime = max(first.time, time - Self.history)
        let second = draft.samples[1]
        let fraction = Float((startTime - first.time) / max(0.0001, second.time - first.time))
        let start = first.point + (second.point - first.point) * fraction
        let velocity = (last.point - start) / Float(max(last.time - startTime, 0.025))
        let speed = simd_length(velocity)
        guard speed > 28 else { return .zero }
        return velocity * min(0.78, 860 / speed)
    }

    /// Swept segment against screen edges and tracked window bounds, so fast throws do not tunnel.
    static func firstImpact(from start: SIMD2<Float>, to end: SIMD2<Float>, radius: Float,
                            size: SIMD2<Float>, windows: [SIMD4<Float>]) -> Float? {
        let delta = end - start
        var first: Float = .infinity
        for axis in 0..<2 {
            if end[axis] < radius && delta[axis] < 0 {
                first = min(first, max(0, (radius - start[axis]) / delta[axis]))
            } else if end[axis] > size[axis] - radius && delta[axis] > 0 {
                first = min(first, max(0, (size[axis] - radius - start[axis]) / delta[axis]))
            }
        }
        for bounds in windows {
            var enter: Float = 0, exit = min(first, 1)
            for axis in 0..<2 {
                let lower = bounds[axis] - radius
                let upper = bounds[axis + 2] + radius
                if abs(delta[axis]) < 0.0001 {
                    if start[axis] < lower || start[axis] > upper { exit = -1; break }
                } else {
                    let a = (lower - start[axis]) / delta[axis]
                    let b = (upper - start[axis]) / delta[axis]
                    enter = max(enter, min(a, b))
                    exit = min(exit, max(a, b))
                }
            }
            if enter <= exit { first = enter }
        }
        return first.isFinite ? first : nil
    }

    private func shatter(at point: SIMD2<Float>, velocity: SIMD2<Float>, diameter: Float) {
        let count = min(32, 7 + Int(diameter * 0.45), Self.maxFragments - fragments.count)
        guard count > 0 else { return }
        let radius = 14 + diameter * 1.45
        let spread = radius * 0.18
        let carry = velocity * 0.09
        let startAngle = Float.random(in: 0...(2 * .pi))
        for i in 0..<count {
            let angle = startAngle + 2 * .pi * (Float(i) + Float.random(in: 0...0.7)) / Float(count)
            let life = Float.random(in: 0.5...0.88)
            let distance = radius * Float.random(in: 0.55...1)
            // Convert distance to launch speed using the same drag as the flight update.
            let speed = (distance - spread) * 3 / (1 - exp(-3 * life))
            let direction = SIMD2(cos(angle), sin(angle))
            fragments.append(Fragment(position: point + direction * spread,
                                      velocity: direction * speed + carry + SIMD2(0, 28),
                                      size: Float.random(in: 1.3...4) * (0.9 + diameter / 140), life: life))
        }
    }

    func writeSprites(into buffer: UnsafeMutablePointer<Sprite>, capacity: Int) -> Int {
        var count = 0
        if let draft = roll, draft.area >= Self.minimumArea, count < capacity {
            buffer[count] = Sprite(position: draft.cursorPosition ?? draft.position,
                                   size: max(2, draft.diameter), alpha: 0.98, soft: 0.23, lump: Self.spriteLump, turn: draft.angle)
            count += 1
        }
        for ball in throwsInFlight where count < capacity {
            buffer[count] = Sprite(position: ball.position, velocity: ball.velocity * 0.22,
                                   size: ball.diameter, alpha: 0.98, soft: 0.23, lump: Self.spriteLump, turn: ball.angle)
            count += 1
        }
        for fragment in fragments where count < capacity {
            let remaining = 1 - fragment.age / fragment.life
            buffer[count] = Sprite(position: fragment.position, velocity: fragment.velocity, size: fragment.size,
                                   alpha: 0.82 * remaining * remaining, soft: 0.42)
            count += 1
        }
        return count
    }
}
