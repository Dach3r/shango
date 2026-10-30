// Shared look of every chart: line design (square corners, hairline grid, no shadows), colors read from the page tokens.
const FONT = "ui-monospace, SFMono-Regular, Menlo, monospace";

export function readTokens(element) {
  const color = (cls) => {
    const probe = document.createElement("span");
    probe.className = cls;
    probe.style.display = "none";
    element.append(probe);
    const value = getComputedStyle(probe).color;
    probe.remove();
    return value;
  };

  return {
    accent: color("text-accent"),
    line: color("text-line"),
    faint: color("text-faint"),
    ink: color("text-ink"),
    card: color("text-card"),
  };
}

export function withAlpha(rgb, alpha) {
  const [r, g, b] = rgb.match(/[\d.]+/g);
  return `rgba(${r}, ${g}, ${b}, ${alpha})`;
}

// Vertical hairline under the hovered point.
export const crosshair = {
  id: "crosshair",
  afterDatasetsDraw(chart, _args, options) {
    const [active] = chart.tooltip?.getActiveElements?.() ?? [];
    if (!active) return;

    const { ctx, chartArea } = chart;
    ctx.save();
    ctx.beginPath();
    ctx.moveTo(active.element.x, chartArea.top);
    ctx.lineTo(active.element.x, chartArea.bottom);
    ctx.lineWidth = 1;
    ctx.strokeStyle = options.color;
    ctx.setLineDash([3, 3]);
    ctx.stroke();
    ctx.restore();
  },
};

export function lineConfig({ labels, datasets, unit, tokens }) {
  const format = (value) => `${Math.round(value)}${unit ? ` ${unit}` : ""}`;

  return {
    type: "line",
    data: {
      labels,
      datasets: datasets.map((dataset) => ({
        label: dataset.label,
        data: dataset.data,
        borderColor: tokens.accent,
        borderWidth: 2,
        borderJoinStyle: "round",
        tension: 0.35,
        cubicInterpolationMode: "monotone",
        spanGaps: false,
        fill: "start",
        backgroundColor: (context) => {
          const { chart } = context;
          if (!chart.chartArea) return "transparent";

          const gradient = chart.ctx.createLinearGradient(0, chart.chartArea.top, 0, chart.chartArea.bottom);
          gradient.addColorStop(0, withAlpha(tokens.accent, 0.28));
          gradient.addColorStop(1, withAlpha(tokens.accent, 0));
          return gradient;
        },
        pointRadius: (context) => {
          const { data, dataIndex } = context;
          const values = data ? data.datasets[0].data : [];
          const lonely = values[dataIndex] != null && values[dataIndex - 1] == null && values[dataIndex + 1] == null;
          return lonely ? 3 : 0;
        },
        pointHoverRadius: 5,
        pointBackgroundColor: tokens.accent,
        pointBorderColor: tokens.card,
        pointBorderWidth: 2,
        pointHitRadius: 12,
      })),
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      animation: { duration: 400 },
      interaction: { mode: "index", intersect: false },
      layout: { padding: { top: 8, right: 4 } },
      scales: {
        x: {
          grid: { display: false },
          border: { color: tokens.line },
          ticks: {
            color: tokens.faint,
            font: { family: FONT, size: 11 },
            maxRotation: 0,
            autoSkip: true,
            maxTicksLimit: 6,
            padding: 8,
          },
        },
        y: {
          beginAtZero: true,
          grace: "10%",
          grid: { color: withAlpha(tokens.line, 0.6), drawTicks: false },
          border: { display: false, dash: [3, 3] },
          ticks: {
            color: tokens.faint,
            font: { family: FONT, size: 11 },
            maxTicksLimit: 4,
            padding: 10,
            callback: (value) => format(value),
          },
        },
      },
      plugins: {
        legend: { display: false },
        crosshair: { color: tokens.faint },
        tooltip: {
          displayColors: false,
          backgroundColor: tokens.card,
          borderColor: tokens.line,
          borderWidth: 1,
          cornerRadius: 0,
          padding: 10,
          titleColor: tokens.faint,
          titleFont: { family: FONT, size: 11, weight: "normal" },
          bodyColor: tokens.ink,
          bodyFont: { family: FONT, size: 13, weight: "bold" },
          callbacks: { label: (context) => format(context.parsed.y) },
        },
      },
    },
  };
}
