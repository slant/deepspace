import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { url: String }

  async submit(event) {
    event.preventDefault()
    const body = this.inputTarget.value.trim()
    if (!body) return

    const response = await fetch(this.urlValue, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ body })
    })

    if (response.ok) {
      this.inputTarget.value = ""
      window.dispatchEvent(new CustomEvent("campaign:updated"))
    }
  }
}
