import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    firstNames: Array,
    lastNames: Array,
    specialties: Array,
    attributesA: Array,
    attributesB: Array
  }
  static targets = ["name", "specialty", "attributeA", "attributeB"]

  randomize() {
    this.nameTarget.value = `${this.#pick(this.firstNamesValue)} ${this.#pick(this.lastNamesValue)}`
    this.specialtyTarget.value = this.#pick(this.specialtiesValue)
    this.attributeATarget.value = this.#pick(this.attributesAValue)
    this.attributeBTarget.value = this.#pick(this.attributesBValue)
  }

  #pick(arr) {
    return arr[Math.floor(Math.random() * arr.length)]
  }
}
