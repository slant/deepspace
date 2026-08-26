import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "body", "choices", "backdrop"]
  static values = { campaignId: String }

  connect() {
    this.onHexSelected = this.openHex.bind(this)
    window.addEventListener("hex:selected", this.onHexSelected)
    this.currentHex = null
    this.currentEventLabel = null
    this.gameOver = false
  }

  disconnect() {
    window.removeEventListener("hex:selected", this.onHexSelected)
  }

  async openHex(event) {
    const { q, r, campaignId } = event.detail
    if (campaignId !== this.campaignIdValue) return

    const url = `/campaigns/${this.campaignIdValue}/hex/${q}/${r}`
    const response = await fetch(url, {
      headers: { Accept: "application/json", "X-CSRF-Token": this.csrfToken }
    })
    if (!response.ok) return

    const data = await response.json()
    this.currentHex = data.hex
    this.currentEventLabel = data.hex?.label || null
    this.show(data)
    Turbo.visit(window.location.href, { frame: "campaign_map" })
    window.dispatchEvent(new CustomEvent("campaign:updated"))
  }

  show(data) {
    this.titleTarget.textContent = data.title || data.hex?.label || "Event"
    this.bodyTarget.innerHTML = this.formatBody(data.body)
    this.choicesTarget.innerHTML = ""

    const hex = data.hex || this.currentHex
    ;(data.choices || []).forEach((choice) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "btn btn-secondary w-full"
      btn.textContent = choice.label
      if (choice.locked) {
        btn.disabled = true
        btn.classList.add("opacity-40", "cursor-not-allowed")
        btn.title = "Requirements not met"
      } else {
        btn.addEventListener("click", () => this.choose(hex, choice))
      }
      this.choicesTarget.appendChild(btn)
    })

    this.dialogTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("modal-open")
  }

  async choose(hex, choice) {
    const url = `/campaigns/${this.campaignIdValue}/hex/${hex.q}/${hex.r}`
    let response, data

    try {
      response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": this.csrfToken
        },
        body: JSON.stringify({
          action_type: choice.action,
          goto_target: choice.metadata?.goto || null,
          scrap_delta: choice.metadata?.scrap_delta || 0,
          fuel_delta:  choice.metadata?.fuel_delta  || 0,
          current_event_label: this.currentEventLabel,
          gain_item: choice.metadata?.gain_item || null,
          lose_item: choice.metadata?.lose_item || null,
          lose_items: choice.metadata?.lose_items || null,
          lose_item_unless: choice.metadata?.lose_item_unless || null,
          mark_sequence: choice.metadata?.mark_sequence || null,
          mark_type: choice.metadata?.mark_type || null,
          gain_random_officer_attribute: choice.metadata?.gain_random_officer_attribute || null,
          gain_random_officer_attribute_count: choice.metadata?.gain_random_officer_attribute_count || null,
          gain_all_officers_attribute: choice.metadata?.gain_all_officers_attribute || null,
          kill_random_officer: choice.metadata?.kill_random_officer || false
        })
      })
    } catch {
      this.bodyTarget.innerHTML = "<p>Connection error. Please try again.</p>"
      return
    }

    if (!response.ok) {
      this.bodyTarget.innerHTML = "<p>Something went wrong. Please try again.</p>"
      return
    }

    data = await response.json()

    window.dispatchEvent(new CustomEvent("campaign:updated"))

    if (data.game_over) {
      this.showGameOver(data)
    } else if (data.next_event) {
      this.currentEventLabel = choice.metadata?.goto || null
      this.show(data.next_event)
    } else {
      Turbo.visit(window.location.href, { frame: "campaign_map" })
      this.close()
    }
  }

  showGameOver(data) {
    this.gameOver = true
    this.titleTarget.textContent = data.title || "Mission Failed"
    this.bodyTarget.innerHTML = this.formatBody(data.body)
    this.choicesTarget.innerHTML = ""

    const btn = document.createElement("button")
    btn.type = "button"
    btn.className = "btn btn-secondary w-full"
    btn.textContent = "Return to Main Menu"
    btn.addEventListener("click", () => this.close())
    this.choicesTarget.appendChild(btn)
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("modal-open")
    if (this.gameOver) Turbo.visit("/campaigns")
  }

  formatBody(text) {
    return (text || "")
      .split("\n")
      .filter((line) => line.trim())
      .map((p) => `<p>${p}</p>`)
      .join("")
  }

  get csrfToken() {
    return document.querySelector("meta[name='csrf-token']")?.content
  }
}
