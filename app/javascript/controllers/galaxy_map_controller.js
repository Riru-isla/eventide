import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "sector", "originInput", "targetInput", "selectionInfo" ]

  connect() {
    this.selectedOrigin = null
    this.selectedTarget = null
  }

  select(event) {
    const el = event.currentTarget
    const sectorId = el.dataset.sectorId
    const sectorInfo = el.dataset.sectorInfo

    if (!this.selectedOrigin) {
      this.selectedOrigin = sectorId
      this.highlight(el, "origin")
      this.originInputTarget.value = sectorId
      this.selectionInfoTarget.textContent = `Origin: ${sectorInfo}. Click a target sector.`
    } else if (!this.selectedTarget && sectorId !== this.selectedOrigin) {
      this.selectedTarget = sectorId
      this.highlight(el, "target")
      this.targetInputTarget.value = sectorId
      this.selectionInfoTarget.textContent = `Origin: ${this.selectedOrigin}, Target: ${sectorInfo}. Dispatch fleet below.`
    } else {
      this.resetSelection()
      this.select(event)
    }
  }

  highlight(element, type) {
    element.classList.add(type === "origin" ? "ring-2" : "ring-2", "ring-white")
    if (type === "origin") {
      element.classList.add("stroke-yellow-400")
    } else {
      element.classList.add("stroke-cyan-400")
    }
  }

  resetSelection() {
    this.selectedOrigin = null
    this.selectedTarget = null
    this.originInputTarget.value = ""
    this.targetInputTarget.value = ""
    this.selectionInfoTarget.textContent = "Click a sector to select origin, then a target."

    this.sectorTargets.forEach(el => {
      el.classList.remove("ring-2", "ring-white", "stroke-yellow-400", "stroke-cyan-400")
    })
  }
}
