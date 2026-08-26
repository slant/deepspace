import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]
  static values = { url: String }

  async submit(event) {
    event.preventDefault()
    if (this.busy) return
    const body = this.inputTarget.value.trim()
    if (!body) return

    this.busy = true
    let response
    try {
      response = await fetch(this.urlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ body })
      })
    } finally {
      this.busy = false
    }

    if (response.ok) {
      this.inputTarget.value = ""
      window.dispatchEvent(new CustomEvent("campaign:updated"))
    }
  }
}
