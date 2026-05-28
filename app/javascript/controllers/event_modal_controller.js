import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "title", "body", "choices", "backdrop"]
  static values = { campaignId: String }

  connect() {
    this.onHexSelected = this.openHex.bind(this)
    window.addEventListener("hex:selected", this.onHexSelected)
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
    this.show(data)
    Turbo.visit(window.location.href, { frame: "campaign_map" })
  }

  show(data) {
    this.titleTarget.textContent = data.title || data.hex?.label || "Event"
    this.bodyTarget.innerHTML = this.formatBody(data.body)
    this.choicesTarget.innerHTML = ""

    ;(data.choices || []).forEach((choice) => {
      const btn = document.createElement("button")
      btn.type = "button"
      btn.className = "btn btn-secondary w-full"
      btn.textContent = choice.label
      btn.addEventListener("click", () => this.choose(data.hex, choice))
      this.choicesTarget.appendChild(btn)
    })

    this.dialogTarget.classList.remove("hidden")
    this.backdropTarget.classList.remove("hidden")
    document.body.classList.add("modal-open")
  }

  async choose(hex, choice) {
    const url = `/campaigns/${this.campaignIdValue}/hex/${hex.q}/${hex.r}`
    await fetch(url, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": this.csrfToken
      },
      body: JSON.stringify({ action_type: choice.action })
    })
    this.close()
    Turbo.visit(window.location.href, { frame: "campaign_map" })
    window.dispatchEvent(new CustomEvent("campaign:updated"))
  }

  close() {
    this.dialogTarget.classList.add("hidden")
    this.backdropTarget.classList.add("hidden")
    document.body.classList.remove("modal-open")
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
