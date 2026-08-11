import { Controller } from "@hotwired/stimulus"

// Ambient backdrop for the HUD. Drawn once per resize rather than animated —
// a static field reads as depth without competing with the numbers.
export default class extends Controller {
  connect() {
    this.context = this.element.getContext("2d")
    this.render = this.render.bind(this)
    this.render()
    window.addEventListener("resize", this.render)
  }

  disconnect() {
    window.removeEventListener("resize", this.render)
  }

  render() {
    const { innerWidth: width, innerHeight: height } = window
    const ratio = Math.min(window.devicePixelRatio || 1, 2)

    this.element.width = width * ratio
    this.element.height = height * ratio
    this.element.style.width = `${width}px`
    this.element.style.height = `${height}px`

    const ctx = this.context
    ctx.setTransform(ratio, 0, 0, ratio, 0, 0)
    ctx.clearRect(0, 0, width, height)

    const count = Math.round((width * height) / 9000)

    for (let i = 0; i < count; i++) {
      const radius = Math.random() * 1.1 + 0.25
      ctx.beginPath()
      ctx.arc(Math.random() * width, Math.random() * height, radius, 0, Math.PI * 2)
      ctx.fillStyle = `rgba(234, 230, 247, ${Math.random() * 0.5 + 0.12})`
      ctx.fill()
    }
  }
}
