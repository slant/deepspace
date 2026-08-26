import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fuel", "scrap", "cargo", "position", "journal"]
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
      if (this.hasCargoTarget) this.cargoTarget.textContent = data.campaign.cargo_sequence
      if (this.hasPositionTarget) this.positionTarget.textContent = data.campaign.current_hex_label
      if (this.hasJournalTarget) this.renderJournal(data.campaign.journal_entries || [])
    }
  }

  renderJournal(entries) {
    this.journalTarget.innerHTML = entries
      .map(
        (entry) => `
          <li class="border-l-2 border-space-700 pl-3">
            <span class="text-xs text-space-400/70">${this.escape(entry.created_at)}</span>
            <p class="text-space-100">${this.escape(entry.body)}</p>
          </li>
        `
      )
      .join("")
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text ?? ""
    return div.innerHTML
  }
}
