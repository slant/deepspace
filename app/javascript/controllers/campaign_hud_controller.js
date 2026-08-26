import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fuel", "scrap", "cargo", "position", "journal", "items", "sequences", "officers", "jumpDrive"]
  static values = { updateUrl: String, jumpDriveUrl: String }

  connect() {
    window.addEventListener("campaign:updated", () => this.reload())
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }

  async jumpDrive() {
    if (!this.hasJumpDriveUrlValue || this.jumpDriveBusy) return
    this.jumpDriveBusy = true

    let response
    try {
      response = await fetch(this.jumpDriveUrlValue, {
        method: "PATCH",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
    } finally {
      this.jumpDriveBusy = false
    }
    if (!response.ok) return

    window.dispatchEvent(new CustomEvent("campaign:updated"))
    Turbo.visit(window.location.href, { frame: "campaign_map" })
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
      if (this.hasJumpDriveTarget) this.jumpDriveTarget.classList.toggle("hidden", !data.campaign.can_jump_drive)
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
            <div class="text-xs text-space-400/80">
              ${this.escape((o.attributes || []).join(", "))}
              ${
                o.fatigue_marks > 0
                  ? `<div class="mt-1 flex items-center gap-1.5">
                      <span class="text-space-400">Fatigue</span>
                      <div class="relative h-3 w-16 overflow-hidden rounded-sm border border-red-900/60 bg-space-800">
                        <div class="h-full bg-red-500/70" style="width: ${Math.round((o.fatigue_marks / o.fatigue_threshold) * 100)}%"></div>
                        <span class="absolute inset-0 flex items-center justify-center font-mono text-[10px] leading-none text-space-100">${o.fatigue_marks}/${o.fatigue_threshold}</span>
                      </div>
                    </div>`
                  : ""
              }
            </div>
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
