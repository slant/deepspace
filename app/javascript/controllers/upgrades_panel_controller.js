import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chevron", "panel", "tracks"]
  static values = { campaignId: String, tracks: Object, progress: Object, scrap: Number }

  connect() {
    this.render()
    this.onUpdated = () => this.reload()
    window.addEventListener("campaign:updated", this.onUpdated)
  }

  disconnect() {
    window.removeEventListener("campaign:updated", this.onUpdated)
  }

  toggle() {
    this.panelTarget.classList.toggle("hidden")
    this.chevronTarget.classList.toggle("rotate-180")
  }

  async reload() {
    const response = await fetch(`/campaigns/${this.campaignIdValue}.json`, {
      headers: { Accept: "application/json" }
    })
    if (!response.ok) return
    const data = await response.json()
    if (!data.campaign) return
    this.progressValue = data.campaign.researched_upgrades || {}
    this.scrapValue = data.campaign.scrap
    this.render()
  }

  async toggleBox(event) {
    const { track, box } = event.currentTarget.dataset
    await this.patch(`/campaigns/${this.campaignIdValue}/upgrades/${track}/boxes/${box}`)
  }

  async complete(event) {
    const { track } = event.currentTarget.dataset
    await this.patch(`/campaigns/${this.campaignIdValue}/upgrades/${track}/complete`)
  }

  async patch(url) {
    let response
    try {
      response = await fetch(url, {
        method: "PATCH",
        headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
      })
    } catch {
      return
    }
    if (!response.ok) return

    const data = await response.json()
    this.progressValue = data.campaign.researched_upgrades || {}
    this.scrapValue = data.campaign.scrap
    this.render()
    window.dispatchEvent(new CustomEvent("campaign:updated"))
  }

  render() {
    this.tracksTarget.innerHTML = Object.entries(this.tracksValue)
      .map(([id, def]) => this.renderTrack(id, def))
      .join("")
  }

  renderTrack(id, def) {
    const progress = this.progressValue[id] || {}
    const marked = progress.marked_boxes || def.boxes.map(() => false)
    const researched = progress.researched === true
    const allMarked = marked.every(Boolean)
    const canAfford = this.scrapValue >= def.scrap_cost

    const boxes = def.boxes
      .map((label, i) => {
        const filled = marked[i]
        const classes = [
          "rounded border px-1.5 py-1 font-mono text-[10px] leading-none transition",
          filled
            ? "border-cyan-400/70 bg-cyan-400/20 text-cyan-200"
            : "border-space-600 bg-space-900 text-space-400 hover:border-space-400",
          researched ? "cursor-default" : "cursor-pointer"
        ].join(" ")
        const action = researched ? "" : `data-action="click->upgrades-panel#toggleBox" data-track="${id}" data-box="${i}"`
        return `<button type="button" class="${classes}" ${researched ? "disabled" : ""} ${action}>${this.escape(label)}</button>`
      })
      .join("")

    const completeButton =
      !researched && allMarked && def.scrap_cost > 0
        ? `<button type="button" class="btn btn-secondary mt-2 w-full text-xs ${canAfford ? "" : "opacity-40 cursor-not-allowed"}"
                   ${canAfford ? `data-action="click->upgrades-panel#complete" data-track="${id}"` : "disabled"}>
             Complete (${def.scrap_cost} scrap)
           </button>`
        : ""

    return `
      <div class="rounded border border-space-700 bg-space-800/60 p-3 ${researched ? "opacity-70" : ""}">
        <div class="flex items-center justify-between">
          <span class="text-sm font-semibold ${researched ? "text-emerald-400" : "text-space-100"}">${this.escape(def.name)}</span>
          ${researched ? '<span class="text-[10px] uppercase tracking-wide text-emerald-400">Researched</span>' : ""}
        </div>
        <div class="mt-2 flex flex-wrap gap-1">${boxes}</div>
        ${completeButton}
      </div>
    `
  }

  escape(text) {
    const div = document.createElement("div")
    div.textContent = text ?? ""
    return div.innerHTML
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
