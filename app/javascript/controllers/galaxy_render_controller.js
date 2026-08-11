import { Controller } from "@hotwired/stimulus"

// Draws the galaxy the sectors sit on: a bright core bulge, logarithmic spiral arms
// scattered with stars, and a faint disc fading to nothing at the rim.
//
// Canvas rather than SVG because this is a few thousand stars — as path data it would
// be enormous and unreadable. The star field is seeded, so it looks identical on every
// redraw instead of reshuffling whenever the window resizes.
export default class extends Controller {
  static values = {
    arms: { type: Number, default: 4 },
    stars: { type: Number, default: 2600 },
    seed: { type: Number, default: 20260812 }
  }

  connect() {
    // NB: not `this.context` — Stimulus resolves this.element through its own
    // this.context, and overwriting it detaches the controller from its scope.
    this.ctx = this.element.getContext("2d")
    this.render = this.render.bind(this)
    this.render()
    window.addEventListener("resize", this.render)
  }

  disconnect() {
    window.removeEventListener("resize", this.render)
  }

  // Small deterministic generator, so the galaxy is the same every time it is drawn.
  seeded() {
    this.state = (this.state * 1664525 + 1013904223) % 4294967296
    return this.state / 4294967296
  }

  render() {
    const size = this.element.clientWidth
    // Nothing to draw into yet — try again once the browser has laid the page out,
    // rather than giving up silently and leaving a blank canvas.
    if (!size) {
      requestAnimationFrame(this.render)
      return
    }

    const ratio = Math.min(window.devicePixelRatio || 1, 2)
    this.element.width = size * ratio
    this.element.height = size * ratio
    this.state = this.seedValue

    const ctx = this.ctx
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, size, size)

    const centre = size / 2
    const radius = size * 0.47

    this.drawDisc(ctx, centre, radius)
    this.drawArms(ctx, centre, radius)
    this.drawCore(ctx, centre, radius)
  }

  drawDisc(ctx, centre, radius) {
    const halo = ctx.createRadialGradient(centre, centre, radius * 0.05, centre, centre, radius)
    halo.addColorStop(0, "rgba(245, 184, 65, 0.16)")
    halo.addColorStop(0.35, "rgba(124, 92, 190, 0.10)")
    halo.addColorStop(0.75, "rgba(44, 38, 80, 0.10)")
    halo.addColorStop(1, "rgba(10, 9, 18, 0)")

    ctx.fillStyle = halo
    ctx.beginPath()
    ctx.arc(centre, centre, radius, 0, Math.PI * 2)
    ctx.fill()
  }

  // Stars scattered along logarithmic spirals, r = a·e^(b·θ), with the scatter widening
  // toward the rim so the arms dissolve rather than ending abruptly.
  drawArms(ctx, centre, radius) {
    const arms = this.armsValue
    const tightness = 0.32

    for (let i = 0; i < this.starsValue; i++) {
      const arm = i % arms
      const along = Math.pow(this.seeded(), 0.62)
      const theta = along * 5.2
      const spread = (0.06 + along * 0.30) * radius

      const distance = radius * 0.08 * Math.exp(tightness * theta)
      if (distance > radius) continue

      const angle = theta + (arm * ((Math.PI * 2) / arms))
      const x = centre + Math.cos(angle) * distance + (this.seeded() - 0.5) * spread
      const y = centre + Math.sin(angle) * distance + (this.seeded() - 0.5) * spread

      const fade = 1 - along
      const size = this.seeded() * 1.15 + 0.2
      const warmth = this.seeded()

      ctx.beginPath()
      ctx.arc(x, y, size, 0, Math.PI * 2)
      ctx.fillStyle = warmth > 0.86
        ? `rgba(245, 184, 65, ${0.16 + fade * 0.5})`
        : `rgba(226, 224, 247, ${0.10 + fade * 0.42})`
      ctx.fill()
    }
  }

  drawCore(ctx, centre, radius) {
    const bulge = ctx.createRadialGradient(centre, centre, 0, centre, centre, radius * 0.20)
    bulge.addColorStop(0, "rgba(255, 236, 196, 0.95)")
    bulge.addColorStop(0.25, "rgba(245, 184, 65, 0.55)")
    bulge.addColorStop(0.65, "rgba(192, 138, 33, 0.18)")
    bulge.addColorStop(1, "rgba(245, 184, 65, 0)")

    ctx.fillStyle = bulge
    ctx.beginPath()
    ctx.arc(centre, centre, radius * 0.20, 0, Math.PI * 2)
    ctx.fill()
  }
}
