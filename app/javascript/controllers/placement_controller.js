import { Controller } from "@hotwired/stimulus";

// Keeps the request name typed so far when the dialog browses to another collection or folder.
export default class extends Controller {
  static targets = ["name"];

  carry(event) {
    const link = event.currentTarget;
    const url = new URL(link.href);
    url.searchParams.set("request_name", this.nameTarget.value);
    link.href = url.toString();
  }
}
