// The app ships its own in-page search, so swallow the browser's find shortcuts (Cmd/Ctrl+F, Cmd/Ctrl+G, F3).
document.addEventListener(
  "keydown",
  (event) => {
    const mod = event.metaKey || event.ctrlKey;
    const key = event.key.toLowerCase();

    if ((mod && !event.altKey && (key === "f" || key === "g")) || key === "f3") {
      event.preventDefault();
    }
  },
  true,
);
