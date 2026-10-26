import { Controller } from "@hotwired/stimulus";

const STORAGE_KEY = "api-client:tree:closed";

export default class extends Controller {
  static targets = ["branch"];

  connect() {
    const closed = this.closed();
    this.branchTargets.forEach((branch) => {
      if (closed.includes(branch.dataset.id)) branch.open = false;
    });
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
