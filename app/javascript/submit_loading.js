// Disables the button that submitted a form and flags it as loading until the response arrives.
// The spinner itself lives in application.css (`button[data-loading]`).
const start = (submitter) => {
  if (!submitter) return;

  submitter.dataset.loading = "true";
  submitter.disabled = true;
};

const stop = (submitter) => {
  if (!submitter) return;

  delete submitter.dataset.loading;
  submitter.disabled = false;
};

document.addEventListener("turbo:submit-start", (event) => start(event.detail.formSubmission.submitter));
document.addEventListener("turbo:submit-end", (event) => stop(event.detail.formSubmission.submitter));

// Forms opted out of Turbo do a full page load, so only the browser's own submit event is seen.
// The button is disabled afterwards because a disabled submitter is left out of the submitted data.
document.addEventListener("submit", (event) => {
  const { submitter, target } = event;
  if (!target.closest('[data-turbo="false"]') || !submitter) return;

  submitter.dataset.loading = "true";
  setTimeout(() => (submitter.disabled = true));
});

// Restoring a page from the back/forward cache must not show a stale spinner.
window.addEventListener("pageshow", (event) => {
  if (event.persisted) document.querySelectorAll("[data-loading]").forEach(stop);
});
