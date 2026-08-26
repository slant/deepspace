import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fuel", "scrap", "cargo", "position", "journal", "items", "sequences", "officers"]
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
      if (this.hasItemsTarget) this.renderItems(data.campaign.items || [])
      if (this.hasSequencesTarget) this.renderSequences(data.campaign.cargo_marks || {})
      if (this.hasOfficersTarget) this.renderOfficers(data.campaign.officers || [])
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

  renderItems(items) {
    if (items.length === 0) {
      this.itemsTarget.innerHTML = `<li class="text-space-400/70 italic">No items yet</li>`
      return
    }
    this.itemsTarget.innerHTML = items
      .map(
        (item) => `<li class="${item.lost ? "text-space-400 line-through" : ""}">[${this.escape(item.name)}]</li>`
      )
      .join("")
  }

  renderSequences(marks) {
    this.sequencesTarget.innerHTML = Object.entries(marks)
      .map(
        ([ token, state ]) => `
          <li class="rounded border border-space-700 bg-space-800 px-1.5 py-0.5 font-mono text-xs ${
            state === "underline" ? "underline" : "ring-1 ring-cyan-400/60"
          }">${this.escape(token)}</li>
        `
      )
      .join("")
  }

  renderOfficers(officers) {
    this.officersTarget.innerHTML = officers
      .map(
        (o) => `
          <li class="${o.dead ? "text-space-400 line-through" : ""}">
            <span class="text-space-100">${this.escape(o.name)}</span>
            <span class="text-space-400"> — ${this.escape(o.title)}, ${this.escape(o.specialty)}</span>
            <div class="text-xs text-space-400/80">${this.escape((o.attributes || []).join(", "))}</div>
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
