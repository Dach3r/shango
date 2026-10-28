import { Controller } from "@hotwired/stimulus";

const EDITOR_LANGUAGE = {
  json: "json",
  xml: "xml",
  text: "text",
  graphql: "graphql",
};

export default class extends Controller {
  static targets = ["select", "panel"];

  connect() {
    this.render();
  }

  change() {
    this.render();
  }

  render() {
    const type = this.selectTarget.value;
    this.element.dataset.bodyType = type;
    this.panelTargets.forEach((panel) => {
      const active = panel.dataset.types.split(" ").includes(type);
      panel.hidden = !active;
    });

    const language = EDITOR_LANGUAGE[type];
    if (language)
      this.dispatch("language", { detail: { language }, prefix: "body-type" });
  }
}
