// Marks the button that submitted a form as loading until the response arrives.
// The spinner itself lives in application.css (`button[data-loading]`).
const start = (submitter) => {
  if (!submitter) return;

  submitter.style.setProperty("--loading-color", getComputedStyle(submitter).color);
  submitter.dataset.loading = "true";
};

const stop = (submitter) => {
  if (!submitter) return;

  delete submitter.dataset.loading;
  submitter.style.removeProperty("--loading-color");
};

document.addEventListener("turbo:submit-start", (event) => start(event.detail.formSubmission.submitter));
document.addEventListener("turbo:submit-end", (event) => stop(event.detail.formSubmission.submitter));

// Forms opted out of Turbo do a full page load, so only the browser's own submit event is seen.
document.addEventListener("submit", (event) => {
  if (event.target.closest('[data-turbo="false"]')) start(event.submitter);
});

// Restoring a page from the back/forward cache must not show a stale spinner.
window.addEventListener("pageshow", (event) => {
  if (event.persisted) document.querySelectorAll("[data-loading]").forEach(stop);
});
