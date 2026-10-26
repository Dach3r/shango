// Turbo keeps the <html> attributes of the page it navigated from, so copy theme, palette and zoom from the incoming page.
const ATTRIBUTES = ["data-theme", "data-palette", "data-zoom"];

document.addEventListener("turbo:before-render", ({ detail: { newBody } }) => {
  const incoming = newBody.ownerDocument.documentElement;

  ATTRIBUTES.forEach((name) => {
    if (incoming.hasAttribute(name)) {
      document.documentElement.setAttribute(name, incoming.getAttribute(name));
    } else {
      document.documentElement.removeAttribute(name);
    }
  });
});
