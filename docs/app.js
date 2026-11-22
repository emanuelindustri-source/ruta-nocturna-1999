(() => {
  "use strict";

  const state = {
    data: null,
    filter: "all",
  };

  const statusNames = {
    completed: "Completada",
    in_progress: "En curso",
    pending: "Pendiente",
  };

  const modelClass = {
    "DS-R": "dsr",
    "DS-S": "dss",
    "MiMo Pro": "pro",
    "MiMo Flash": "flash",
  };

  const escapeHtml = (value) =>
    String(value)
      .replaceAll("&", "&amp;")
      .replaceAll("<", "&lt;")
      .replaceAll(">", "&gt;")
      .replaceAll('"', "&quot;")
      .replaceAll("'", "&#039;");

  const $ = (selector) => document.querySelector(selector);
  const $$ = (selector) => Array.from(document.querySelectorAll(selector));

  function setText(selector, text) {
    const node = $(selector);
    if (node) node.textContent = text;
  }

  function setProgress(percent) {
    const bar = $("#progress-bar");
    const label = $("#progress-label");
    const progress = $(".progress");
    if (bar) bar.style.width = `${percent}%`;
    if (progress) progress.setAttribute("aria-valuenow", String(percent));
    if (label) {
      const completed = state.data?.summary.completed ?? 0;
      const total = state.data?.summary.total ?? 0;
      label.textContent = `${completed} / ${total} hitos completados · ${percent}%`;
    }
  }

  function phaseVisibleSubphases(phase) {
    if (state.filter === "all") return phase.subphases;
    return phase.subphases.filter((sub) => sub.status === state.filter);
  }

  function visibleStatusCounts() {
    if (!state.data) return { completed: 0, in_progress: 0, pending: 0, total: 0 };
    const subs = state.data.phases.flatMap((phase) => phaseVisibleSubphases(phase));
    return subs.reduce(
      (acc, sub) => {
        acc[sub.status] = (acc[sub.status] || 0) + 1;
        acc.total += 1;
        return acc;
      },
      { completed: 0, in_progress: 0, pending: 0, total: 0 },
    );
  }

  function renderSummary() {
    const target = $("#roadmap-summary");
    if (!target) return;
    const counts = visibleStatusCounts();
    target.innerHTML = `
      <span class="summary-chip"><strong>${counts.completed}</strong> completadas</span>
      <span class="summary-chip"><strong>${counts.in_progress}</strong> en curso</span>
      <span class="summary-chip"><strong>${counts.pending}</strong> pendientes</span>
      <span class="summary-chip">Mostrando <strong>${counts.total}</strong> de ${state.data.summary.total} hitos</span>
    `;
    setText("#roadmap-count", `${state.data.current_version} · ${state.data.current_subphase} en foco`);
  }

  function renderSubphase(sub) {
    const model = escapeHtml(sub.model);
    return `
      <li class="subphase">
        <div class="subphase-id">${escapeHtml(sub.id)}</div>
        <div>
          <div class="subphase-row">
            <span class="version-tag">${escapeHtml(sub.version)}</span>
            <span class="model ${modelClass[sub.model] || ""}" title="${escapeHtml(sub.model_label)}">${model}</span>
            <span class="status-pill status-${escapeHtml(sub.status)}">${escapeHtml(statusNames[sub.status] || sub.status)}</span>
          </div>
          <p class="subphase-summary">${escapeHtml(sub.summary)}</p>
        </div>
      </li>
    `;
  }

  function renderPhase(phase, index) {
    const subphases = phaseVisibleSubphases(phase);
    if (!subphases.length) return "";

    const open = state.filter !== "all" || phase.status === "in_progress" || index === 0;
    const completed = phase.progress.completed;
    const total = phase.progress.total;
    const percent = Math.round((completed / total) * 100);
    const phaseId = `phase-body-${phase.id}`;

    return `
      <article class="phase-card ${open ? "is-open" : ""}" data-phase="${phase.id}">
        <button class="phase-toggle" type="button" aria-expanded="${open}" aria-controls="${phaseId}">
          <div>
            <p class="phase-kicker">FASE ${String(phase.id).padStart(2, "0")} · ${escapeHtml(phase.version_range)}</p>
            <h3 class="phase-title">${escapeHtml(phase.title)}</h3>
          </div>
          <div class="phase-meta">
            <span class="status-pill status-${escapeHtml(phase.status)}">${escapeHtml(statusNames[phase.status])}</span>
            <span>${phase.progress.completed}/${phase.progress.total} hitos</span>
          </div>
          <div class="phase-progress" aria-hidden="true">
            <div class="mini-line"><span style="width:${percent}%"></span></div>
            <small>${percent}%</small>
          </div>
        </button>
        <div class="phase-body" id="${phaseId}">
          <ol class="subphase-list">
            ${subphases.map(renderSubphase).join("")}
          </ol>
        </div>
      </article>
    `;
  }

  function renderRoadmap() {
    const target = $("#roadmap-list");
    if (!target || !state.data) return;
    target.innerHTML = state.data.phases.map(renderPhase).join("");

    target.querySelectorAll(".phase-toggle").forEach((button) => {
      button.addEventListener("click", () => {
        const card = button.closest(".phase-card");
        const isOpen = card.classList.toggle("is-open");
        button.setAttribute("aria-expanded", String(isOpen));
      });
    });

    renderSummary();
  }

  function renderStatus() {
    const data = state.data;
    if (!data) return;
    setText("#status-version", data.current_version);
    const currentPhase = data.phases.find((phase) => phase.status === "in_progress");
    setText(
      "#status-phase",
      currentPhase
        ? `Fase ${currentPhase.id} · ${currentPhase.title}`
        : `Fase ${data.current_subphase} · en preparación`,
    );
    setProgress(data.summary.percent);

    const current = data.phases
      .flatMap((phase) => phase.subphases)
      .find((sub) => sub.id === data.current_subphase);
    if (current) {
      setText(
        "#status-copy",
        current.status === "in_progress"
          ? "La carretera todavía no es jugable. Los cimientos sí."
          : "El proyecto avanza. Las mecánicas se incorporan por hitos validados.",
      );
      const next = data.phases
        .flatMap((phase) => phase.subphases)
        .find((sub) => sub.status !== "completed");
      if (next) setText("#next-gate", `FASE ${next.id}`);
    }

    const nextPending = data.phases
      .flatMap((phase) => phase.subphases)
      .find((sub) => sub.status === "pending");
    if (nextPending) setText("#next-gate", `FASE ${nextPending.id}`);
  }

  function setupFilters() {
    $$(".filter").forEach((button) => {
      button.addEventListener("click", () => {
        state.filter = button.dataset.filter || "all";
        $$(".filter").forEach((item) => item.classList.toggle("is-active", item === button));
        renderRoadmap();
      });
    });
  }

  function setupNav() {
    const toggle = $(".nav-toggle");
    const nav = $("#site-nav");
    if (!toggle || !nav) return;
    toggle.addEventListener("click", () => {
      const open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", String(open));
    });
    nav.querySelectorAll("a").forEach((link) => {
      link.addEventListener("click", () => {
        nav.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
      });
    });
  }

  function showFailure(message) {
    const target = $("#roadmap-list");
    if (target) {
      target.innerHTML = `<p class="roadmap-error">No se pudo cargar el roadmap: ${escapeHtml(message)}. Ejecuta <code>tools/release/sync_roadmap.py</code> y sirve la página desde HTTP.</p>`;
    }
  }

  async function init() {
    setText("#year", String(new Date().getFullYear()));
    setupNav();
    setupFilters();
    try {
      const response = await fetch("roadmap-data.json", { cache: "no-store" });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      state.data = await response.json();
      if (!state.data.phases || !state.data.summary) throw new Error("JSON incompleto");
      renderStatus();
      renderRoadmap();
    } catch (error) {
      showFailure(error instanceof Error ? error.message : String(error));
    }
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", init, { once: true });
  } else {
    init();
  }
})();
