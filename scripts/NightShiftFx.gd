class_name NightShiftFx
extends RefCounted
# Procedural effects + telegraph system for NightShiftGame.
#
# Three concerns, all data-driven:
#   1. PARTICLES    — short-lived procedural shapes drawn by NightShiftGame
#                     via CanvasItem.draw_circle / draw_rect each frame.
#   2. SHAKE        — impulse-based camera shake offset, applied to layers
#                     that want to react (hotspot_layer, enemy_layer, etc).
#   3. TELEGRAPHS   — pre-impact warning indicators on hotspots. Schedules
#                     a warning N seconds before an assault actually hits,
#                     giving the player time to react.
#
# The module is a static utility — call NightShiftFx.spawn_particle(...) and
# the caller owns the array. This keeps the data on the game's side (which
# already has a _draw() override) and avoids spawning any extra nodes.

# ---- particle kinds --------------------------------------------------------

const PARTICLE_KIND_DOT := 0
const PARTICLE_KIND_RECT := 1
const PARTICLE_KIND_RING := 2  # expanding ring (for radio contact, breach)

# ---- particle struct (dictionary shape) ------------------------------------
# {pos: Vector2, vel: Vector2, life: float, max_life: float, color: Color,
#  size: float, kind: int, gravity: float, fade: bool}


# Spawn a single particle into a particle array. Returns the entry so the
# caller can pin custom fields (e.g. a "lifetime fade curve") if needed.
static func spawn_particle(
    particles: Array,
    pos: Vector2,
    vel: Vector2,
    life: float,
    color: Color,
    size: float,
    kind: int = PARTICLE_KIND_DOT,
    gravity: float = 0.0,
    fade: bool = true
) -> Dictionary:
    var p := {
        "pos": pos,
        "vel": vel,
        "life": life,
        "max_life": life,
        "color": color,
        "size": size,
        "kind": kind,
        "gravity": gravity,
        "fade": fade,
    }
    particles.append(p)
    return p


# Advance a particle list by dt seconds. Mutates entries in-place and
# drops dead ones. Returns the count that died this frame (for sound hooks).
static func tick_particles(particles: Array, dt: float) -> int:
    var deaths := 0
    var i: int = particles.size() - 1
    while i >= 0:
        var p: Dictionary = particles[i]
        p["life"] -= dt
        if p["life"] <= 0.0:
            particles.remove_at(i)
            deaths += 1
        else:
            var v: Vector2 = p["vel"]
            v.y += p["gravity"] * dt
            p["vel"] = v
            p["pos"] += v * dt
        i -= 1
    return deaths


# Draw a particle list on the given CanvasItem. Call from _draw() or
# _process() with a queue_redraw() afterwards.
static func draw_particles(canvas_item: CanvasItem, particles: Array) -> void:
    for p in particles:
        var life_ratio: float = float(p["life"]) / max(0.001, float(p["max_life"]))
        var color: Color = p["color"]
        if p["fade"]:
            color.a *= life_ratio
        var pos: Vector2 = p["pos"]
        var size: float = float(p["size"])
        match int(p["kind"]):
            PARTICLE_KIND_DOT:
                canvas_item.draw_circle(pos, size, color)
            PARTICLE_KIND_RECT:
                canvas_item.draw_rect(Rect2(pos - Vector2(size, size), Vector2(size * 2.0, size * 2.0)), color)
            PARTICLE_KIND_RING:
                # Ring is a hollow circle; draw an outer color then punch with
                # transparent — CanvasItem has no draw_arc_ring, so fake it
                # with an outer dot whose alpha is the life ratio.
                canvas_item.draw_circle(pos, size * (1.5 - life_ratio), color)


# Convenience burst spawns used by NightShiftGame on common events. Each
# returns the particle array (passed in) so calls can chain.

# Crack burst — used when a window takes damage.
static func burst_window_crack(particles: Array, pos: Vector2, intensity: float = 1.0) -> void:
    var n: int = int(8 * intensity)
    for i in n:
        var ang: float = randf() * TAU
        var speed: float = 80.0 + randf() * 120.0
        spawn_particle(
            particles,
            pos,
            Vector2(cos(ang), sin(ang)) * speed,
            0.5 + randf() * 0.4,
            Color(0.85, 0.92, 1.0, 0.9),
            1.5 + randf() * 1.5,
            PARTICLE_KIND_DOT,
            200.0
        )

# Splinter burst — used when a door takes damage.
static func burst_door_splinter(particles: Array, pos: Vector2, intensity: float = 1.0) -> void:
    var n: int = int(10 * intensity)
    for i in n:
        var ang: float = randf() * TAU
        var speed: float = 60.0 + randf() * 100.0
        spawn_particle(
            particles,
            pos,
            Vector2(cos(ang), sin(ang)) * speed,
            0.6 + randf() * 0.5,
            Color(0.7, 0.5, 0.35, 0.95),
            2.0 + randf() * 2.0,
            PARTICLE_KIND_RECT,
            280.0
        )

# Spark burst — used when the generator drops or flickers.
static func burst_spark(particles: Array, pos: Vector2, intensity: float = 1.0) -> void:
    var n: int = int(12 * intensity)
    for i in n:
        var ang: float = randf() * TAU
        var speed: float = 100.0 + randf() * 200.0
        spawn_particle(
            particles,
            pos,
            Vector2(cos(ang), sin(ang)) * speed,
            0.3 + randf() * 0.3,
            Color(1.0, 0.85, 0.3, 1.0),
            1.0 + randf() * 1.5,
            PARTICLE_KIND_DOT,
            120.0
        )

# Breach explosion — big radial burst when a hotspot fully breaches.
static func burst_breach(particles: Array, pos: Vector2, intensity: float = 1.0) -> void:
    var n: int = int(24 * intensity)
    for i in n:
        var ang: float = randf() * TAU
        var speed: float = 120.0 + randf() * 280.0
        spawn_particle(
            particles,
            pos,
            Vector2(cos(ang), sin(ang)) * speed,
            0.8 + randf() * 0.6,
            Color(0.95, 0.25, 0.15, 1.0),
            2.5 + randf() * 2.5,
            PARTICLE_KIND_DOT,
            180.0
        )
        spawn_particle(
            particles,
            pos,
            Vector2(cos(ang), sin(ang)) * speed * 0.6,
            0.5 + randf() * 0.4,
            Color(1.0, 0.7, 0.2, 0.9),
            3.0 + randf() * 2.0,
            PARTICLE_KIND_RING,
            0.0
        )

# Radio contact ring — single soft ring at the radio when a contact completes.
static func burst_radio_contact(particles: Array, pos: Vector2) -> void:
    for i in 6:
        var ang: float = (TAU / 6.0) * float(i)
        spawn_particle(
            particles,
            pos,
            Vector2(cos(ang), sin(ang)) * 180.0,
            0.6,
            Color(0.6, 0.9, 1.0, 0.95),
            6.0,
            PARTICLE_KIND_RING,
            0.0
        )

# ---- screen shake -----------------------------------------------------------

# State shape:
# {amount: float, decay: float, freq: float, phase: float}
# Tick by dt; apply_offset() returns a Vector2 to add to a layer's position.

static func shake_trigger(state: Dictionary, amount: float, decay: float = 6.0, freq: float = 28.0) -> void:
    # Stack impulses: take the larger of current amount and new amount.
    var current: float = float(state.get("amount", 0.0))
    state["amount"] = max(current, amount)
    state["decay"] = decay
    state["freq"] = freq


static func shake_tick(state: Dictionary, dt: float) -> void:
    var amt: float = float(state.get("amount", 0.0))
    if amt <= 0.0:
        state["amount"] = 0.0
        return
    amt -= float(state.get("decay", 6.0)) * dt
    if amt < 0.0:
        amt = 0.0
    state["amount"] = amt
    state["phase"] = float(state.get("phase", 0.0)) + dt


static func shake_offset(state: Dictionary) -> Vector2:
    var amt: float = float(state.get("amount", 0.0))
    if amt <= 0.0:
        return Vector2.ZERO
    var freq: float = float(state.get("freq", 28.0))
    var phase: float = float(state.get("phase", 0.0))
    # Cheap 2D noise: two sines at different frequencies. Good enough that it
    # doesn't look like a pure vertical bounce.
    var nx: float = sin(phase * freq) + sin(phase * freq * 1.7 + 1.3) * 0.6
    var ny: float = cos(phase * freq * 0.9) + sin(phase * freq * 1.4 + 0.4) * 0.6
    return Vector2(nx, ny) * amt


# ---- telegraph system -------------------------------------------------------
# A telegraph is a {hotspot_id, time_left, kind} entry. When scheduled,
# NightShiftGame renders a pulsing warning indicator on the hotspot. When
# the timer hits zero, the actual assault event fires.

static func telegraph_schedule(
    telegraphs: Array,
    hotspot_id: String,
    lead_time: float,
    kind: String = "assault"
) -> void:
    # If already scheduled for this hotspot + kind, extend it rather than
    # stack — prevents overlapping warnings from looking chaotic.
    for t in telegraphs:
        if t["hotspot_id"] == hotspot_id and t["kind"] == kind:
            t["time_left"] = max(float(t["time_left"]), lead_time)
            return
    telegraphs.append({
        "hotspot_id": hotspot_id,
        "time_left": lead_time,
        "total_time": lead_time,
        "kind": kind,
        "fired": false,
    })


static func telegraph_tick(telegraphs: Array, dt: float) -> Array:
    # Returns entries that just transitioned to 0 this frame (caller fires
    # the actual event — assault / breach / etc).
    var fired: Array = []
    var i: int = telegraphs.size() - 1
    while i >= 0:
        var t: Dictionary = telegraphs[i]
        t["time_left"] -= dt
        if t["time_left"] <= 0.0:
            if not bool(t.get("fired", false)):
                fired.append(t.duplicate())
                t["fired"] = true
            # Keep the entry for half a second so the visual "just landed"
            # indicator can fade. Drop it after that.
            t["time_left"] += dt  # re-add so it stays ~0
            # Use a separate cleanup pass instead:
            telegraphs.remove_at(i)
        i -= 1
    return fired


static func telegraph_pulse_alpha(t: Dictionary) -> float:
    # 0..1 alpha for the warning indicator. Pulses faster as the timer drains.
    var ratio: float = clamp(float(t["time_left"]) / max(0.001, float(t["total_time"])), 0.0, 1.0)
    var pulse_speed: float = 3.0 + (1.0 - ratio) * 12.0
    return 0.35 + 0.65 * (0.5 + 0.5 * sin(float(t.get("phase", 0.0)) * pulse_speed))


static func telegraph_phase_tick(telegraphs: Array, dt: float) -> void:
    for t in telegraphs:
        t["phase"] = float(t.get("phase", 0.0)) + dt
