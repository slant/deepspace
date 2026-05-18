import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fuel", "scrap", "cargo"]
  static values = { updateUrl: String }

  connect() {
    window.addEventListener("campaign:updated", () => this.reload())
  }

  async reload() {
    if (!this.hasUpdateUrlValue) return
    const response = await fetch(this.updateUrlValue, { headers: { Accept: "application/json" } })
    if (!response.ok) return
    const data = await response.json()
    if (data.campaign) {
      if (this.hasFuelTarget) this.fuelTarget.textContent = data.campaign.fuel
      if (this.hasScrapTarget) this.scrapTarget.textContent = data.campaign.scrap
    }
  }
}
