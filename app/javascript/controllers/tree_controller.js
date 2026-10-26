import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "api-client:tree:closed";

export default class extends Controller {
  static targets = ["branch"];
  static values = {
    toggle: { type: String, default: "double_click" },
    open: { type: String, default: "click" },
  };

  connect() {
    this.requestClick = (event) => this.guardRequest(event, false);
    this.requestDoubleClick = (event) => this.guardRequest(event, true);
    // Capture phase: runs before the row's own click handling (delayed navigation, rename).
    this.element.addEventListener("click", this.requestClick, true);
    this.element.addEventListener("dblclick", this.requestDoubleClick, true);

    const closed = this.closed();
    this.branchTargets.forEach((branch) => {
      if (closed.includes(branch.dataset.id)) branch.open = false;
    });
  }

  disconnect() {
    this.element.removeEventListener("click", this.requestClick, true);
    this.element.removeEventListener("dblclick", this.requestDoubleClick, true);
  }

  // With double click opening, a request link only navigates on a double click (names do not rename then).
  guardRequest(event, double) {
    if (this.openValue !== "double_click") return;

    const link = event.target.closest("[data-drag-kind='request'] a");
    if (!link) return;

    event.preventDefault();
    event.stopPropagation();
    if (double) window.Turbo.visit(link.href);
  }

  toggled(event) {
    const branch = event.currentTarget;
    const closed = new Set(this.closed());
    branch.open
      ? closed.delete(branch.dataset.id)
      : closed.add(branch.dataset.id);
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify([...closed]));
    } catch (_) {
      /* storage unavailable */
    }
  }

  // With double click toggling, a plain click on a branch row must not open or close it.
  // The chevron always toggles on a single click.
  summaryClick(event) {
    if (this.onArrow(event)) return;

    if (this.toggleValue === "double_click") event.preventDefault();
  }

  // Names rename on double click (inline-rename stops the event), so this only sees the rest of the row.
  summaryDoubleClick(event) {
    if (this.toggleValue !== "double_click" || this.onArrow(event)) return;

    const branch = event.currentTarget.closest("details");
    branch.open = !branch.open;
  }

  onArrow(event) {
    return Boolean(event.target.closest("[data-tree-arrow]"));
  }

  dragStart(event) {
    const item = event.currentTarget;
    event.stopPropagation();
    this.dragged = {
      kind: item.dataset.dragKind,
      id: item.dataset.dragId,
      url: item.dataset.positionUrl,
      collectionId: item.dataset.collectionId,
    };
    event.dataTransfer.effectAllowed = "move";
    event.dataTransfer.setData("text/plain", this.dragged.id);
  }

  dragEnd() {
    this.dragged = null;
    this.clearTargets();
  }

  dragOver(event) {
    if (!this.dragged) return;

    const target = this.dropTarget(event);
    if (!target || !this.allowed(target)) return;

    event.preventDefault();
    event.stopPropagation();
    this.clearTargets();
    target.element.dataset.dropActive = target.mode;
  }

  async drop(event) {
    if (!this.dragged) return;

    const target = this.dropTarget(event);
    if (!target || !this.allowed(target)) return;

    event.preventDefault();
    event.stopPropagation();
    const dragged = this.dragged;
    this.dragEnd();

    const params = new URLSearchParams({ before_id: target.beforeId || "" });
    if (dragged.kind === "request") {
      params.set("collection_id", target.collectionId);
      params.set("folder_id", target.folderId || "");
    } else {
      params.set("parent_id", target.folderId || "");
    }

    const response = await fetch(dragged.url, {
      method: "PATCH",
      body: params,
      headers: {
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")
          ?.content,
      },
      credentials: "same-origin",
    });
    if (response.ok)
      window.Turbo.visit(window.location.href, { action: "replace" });
  }

  // `before`: insert ahead of an item; `into`: append inside a folder or collection root.
  dropTarget(event) {
    const element = event.target.closest("[data-drop-mode]");
    if (!element) return null;

    return {
      element,
      mode: element.dataset.dropMode,
      collectionId: element.dataset.collectionId,
      folderId: element.dataset.folderId,
      beforeId:
        element.dataset.dropMode === "before" ? element.dataset.dragId : null,
      targetId: element.dataset.dragId,
    };
  }

  allowed(target) {
    if (target.targetId === this.dragged.id) return false;
    if (
      this.dragged.kind === "folder" &&
      target.collectionId !== this.dragged.collectionId
    )
      return false;

    return true;
  }

  clearTargets() {
    this.element
      .querySelectorAll("[data-drop-active]")
      .forEach((element) => delete element.dataset.dropActive);
  }

  closed() {
    try {
      return JSON.parse(localStorage.getItem(STORAGE_KEY) || "[]");
    } catch (_) {
      return [];
    }
  }
}
