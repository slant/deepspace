import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["svg", "scroll"]
  static values = { campaignId: String }

  selectHex(event) {
    event.stopPropagation()
    const cell = event.currentTarget
    const q = cell.dataset.q
    const r = cell.dataset.r
    if (q === undefined || r === undefined) return

    window.dispatchEvent(
      new CustomEvent("hex:selected", {
        detail: {
          q: parseInt(q, 10),
          r: parseInt(r, 10),
          label: cell.dataset.label,
          campaignId: this.campaignIdValue
        }
      })
    )
  }
}
