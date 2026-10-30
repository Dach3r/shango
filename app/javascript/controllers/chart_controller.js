import { Controller } from "@hotwired/stimulus";
import { crosshair, lineConfig, readTokens } from "lib/charts";

// Draws a Chart.js chart on its canvas from the server's data. Redrawn when the theme or palette changes and when a
// Turbo refresh brings new data.
export default class extends Controller {
  static targets = ["canvas"];
  static values = {
    labels: { type: Array, default: [] },
    datasets: { type: Array, default: [] },
    unit: String,
  };

  async connect() {
    const token = (this.token = Symbol("connect"));
    const { Chart } = await import("chart.js");
    if (this.token !== token) return;

    this.Chart = Chart;
    this.draw();
    this.observer = new MutationObserver(() => this.draw());
    this.observer.observe(document.documentElement, { attributes: true, attributeFilter: ["data-theme", "data-palette"] });
    this.scheme = matchMedia("(prefers-color-scheme: dark)");
    this.scheme.addEventListener("change", this.redraw);
    this.element.dataset.ready = "true";
  }

  disconnect() {
    this.token = null;
    this.observer?.disconnect();
    this.scheme?.removeEventListener("change", this.redraw);
    this.chart?.destroy();
    this.chart = null;
  }

  labelsValueChanged() {
    this.redraw();
  }

  datasetsValueChanged() {
    this.redraw();
  }

  redraw = () => {
    if (this.Chart) this.draw();
  };

  draw() {
    this.chart?.destroy();
    this.chart = new this.Chart(this.canvasTarget, {
      ...lineConfig({
        labels: this.labelsValue,
        datasets: this.datasetsValue,
        unit: this.unitValue,
        tokens: readTokens(this.element),
      }),
      plugins: [crosshair],
    });
  }
}
