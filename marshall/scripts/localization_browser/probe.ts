import { always } from "@antithesishq/bombadil";
import { actions, extract, registerCustomAction } from "@antithesishq/bombadil/browser";
export { noUncaughtExceptions, noUnhandledPromiseRejections } from "@antithesishq/bombadil/browser/defaults/properties";
const locales = ["en", "zh-Hans", "hi", "es", "ar", "fr", "bn", "pt-BR", "pt-PT", "ru", "ur", "id", "de", "ja", "pcm", "mr", "te", "tr", "ta", "vi", "ko", "fil", "et", "fi", "sv", "arz", "sw", "ha"] as const;
// @cc [owner:ghuntley,label:verification] localized-route-browser-boundary
// Real browser actions MUST use the application's controls and session. The
// fixture's synthetic inventory MUST NOT establish native guest execution.
const presentation = extract((state) => {
  const root = state.document.documentElement;
  const read = (key: string): string => { try { return state.window.sessionStorage.getItem(key) || ""; } catch { return ""; } };
  const languageSelect = state.document.querySelector('#language-form select[name="language[locale]"]');
  return {
    authenticatedSettings: state.document.querySelector("#language-form") !== null,
    language: root.lang,
    direction: root.dir,
    computedDirection: state.window.getComputedStyle(root).direction,
    overflow: root.scrollWidth > state.window.innerWidth + 1,
    invalidCodeDirection: Array.from(state.document.querySelectorAll("pre")).some((element) => state.window.getComputedStyle(element).direction !== "ltr"),
    savePoint: (() => { const button = state.document.querySelector("#save-language"); const rect = button?.getBoundingClientRect(); return {x: rect ? rect.x + rect.width / 2 : 0, y: rect ? rect.y + rect.height / 2 : 0}; })(),
    phase: read("localization.phase") || "submit",
    selectValue: languageSelect instanceof HTMLSelectElement ? languageSelect.value : "",
    csrfPresent: Boolean(state.document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")),
    socketMethodPresent: (() => { const socket: unknown = Reflect.get(state.window, "liveSocket"); return typeof socket === "object" && socket !== null && "isConnected" in socket && typeof socket.isConnected === "function"; })(),
    socketPresent: typeof Reflect.get(state.window, "liveSocket") === "object",
    socketConnected: (() => { const socket: unknown = Reflect.get(state.window, "liveSocket"); return typeof socket === "object" && socket !== null && "isConnected" in socket && typeof socket.isConnected === "function" && socket.isConnected() === true; })(),
    formValid: (() => { const form = state.document.querySelector("#language-form"); return form instanceof HTMLFormElement && form.checkValidity(); })(),
    errorFlash: state.document.querySelector("#flash-error")?.textContent?.includes("Choose") || false,
    submitDisabled: (() => { const button = state.document.querySelector("#save-language"); return button instanceof HTMLButtonElement && button.disabled; })(),
    savedOverride: state.document.querySelector("#clear-language") !== null,
    connected: state.document.querySelector("#language-form")?.closest(".phx-connected") !== null,
    width: state.window.innerWidth,
    height: state.window.innerHeight,
    desiredHeight: Number(read("localization.matrixIndex") || "0") % 2 === 0 ? 844 : 1000,
    desiredWidth: Number(read("localization.matrixIndex") || "0") % 2 === 0 ? 390 : 1440,
    matrix: read("localization.matrix") || "",
    covered: read("localization.covered") || "",
    reloaded: read("localization.reloaded") || "",
    repeatedSaveVerified: read("localization.repeatVerified") === "yes",
    resetVerified: read("localization.resetVerified") === "yes",
    completed: read("localization.completed") === "yes",
    routeCoverage: read("localization.routes"),
    pinChecks: read("localization.pins"),
    rtlMixedData: read("localization.rtlMixedData"),
    cloneChecks: read("localization.clones"),
    routePhase: read("localization.phase") === "routes",
    application: state.document.querySelector("#main-content") !== null,
    lostAuthentication: read("localization.authenticated") === "yes" && state.window.location.pathname === "/sign-in",
  };
});
export const keptAuthentication = always(() => !presentation.current.lostAuthentication);
export const matchingDirection = always(() => !presentation.current.authenticatedSettings || presentation.current.direction === (["ar", "ur", "arz"].includes(presentation.current.language) ? "rtl" : "ltr"));
export const appliedDirection = always(() => !presentation.current.authenticatedSettings || presentation.current.computedDirection === presentation.current.direction);
export const validLocale = always(() => !presentation.current.authenticatedSettings || locales.some((locale) => locale === presentation.current.language));
export const noDocumentOverflow = always(() => !presentation.current.authenticatedSettings || !presentation.current.overflow);
export const codeRemainsLtr = always(() => !presentation.current.invalidCodeDirection);
const advance = registerCustomAction("deterministicLocalizationAdvance", async (document, window) => {
  if (!["http:", "https:"].includes(window.location.protocol) || !["localhost", "127.0.0.1"].includes(window.location.hostname)) throw new Error("Only disposable loopback fixtures are accepted.");
  const store = window.sessionStorage;
  const path = window.location.pathname;
  if (path.startsWith("/magic_link/")) {
    // LiveView's phx-trigger-action submits the ordinary CSRF-protected form.
    // Wait here so a second programmatic POST cannot consume its one-use token.
    return;
  }
  if (path === "/sign-in") throw new Error("Fixture authentication did not complete; use a fresh unconsumed fixture link.");
  if (store.getItem("localization.phase") === "routes") {
    const allowed = ["en", "zh-Hans", "hi", "es", "ar", "fr", "bn", "pt-BR", "pt-PT", "ru", "ur", "id", "de", "ja", "pcm", "mr", "te", "tr", "ta", "vi", "ko", "fil", "et", "fi", "sv", "arz", "sw", "ha"];
    const expected = allowed[Number(store.getItem("localization.index") || "0")];
    if (!expected) throw new Error("Invalid route locale index.");
    const routes = ["/overview", "/machines", "/docs", "/docs/quickstart"];
    const routeIndex = Number(store.getItem("localization.routeIndex") || "0");
    const route = routes[routeIndex];
    if (!route) throw new Error("Invalid localization route index.");
    if (path !== route) { window.location.href = route; return; }
    const publicDocs = route.startsWith("/docs");
    if (!publicDocs && !document.querySelector("[data-phx-main].phx-connected")) return;
    // Public documentation deliberately ignores account cookies and uses the
    // launcher's Japanese Accept-Language header, preserving its public boundary.
    if (document.documentElement.lang !== (publicDocs ? "ja" : expected)) throw new Error("Route locale did not follow its authority.");
    if (document.documentElement.dir !== (["ar", "arz", "ur"].includes(publicDocs ? "ja" : expected) ? "rtl" : "ltr")) throw new Error("Route direction mismatches.");
    if (publicDocs && !document.querySelector("#public-documentation")) throw new Error("Localized public guide is absent.");
    if (route === "/machines") {
      const rows = Array.from(document.querySelectorAll("#machines tr.machine-row"));
      const resources = document.querySelector("#machines .resource-values");
      if (["ar", "arz", "ur"].includes(expected) && resources && (!resources.textContent?.includes("\u2068") || !resources.textContent.includes("\u2069"))) throw new Error("RTL resource interpolation lost its mixed-data isolation.");
      const pinPhase = store.getItem("localization.pinPhase") || "start";
      if (rows.length > 1 && pinPhase === "start") {
        const row = rows.slice(1).find((row) => row.querySelector('button.pin-toggle[aria-pressed="false"]'));
        const toggle = row?.querySelector("button.pin-toggle");
        if (row && toggle instanceof HTMLButtonElement) {
          store.setItem("localization.pinRows", JSON.stringify(rows.map((row) => row.id)));
          store.setItem("localization.pinTarget", row.id);
          store.setItem("localization.pinPhase", "pinned"); toggle.click(); return;
        }
      }
      if (pinPhase === "pinned") {
        const target = store.getItem("localization.pinTarget");
        const first = rows[0];
        const toggle = first?.querySelector('button.pin-toggle[aria-pressed="true"]');
        if (first?.id !== target || !(toggle instanceof HTMLButtonElement)) return;
        if (new Set(rows.map((row) => row.id)).size !== rows.length) throw new Error("Pin duplicated a machine row.");
        store.setItem("localization.pinPhase", "unpinned"); toggle.click(); return;
      }
      if (pinPhase === "unpinned") {
        if (JSON.stringify(rows.map((row) => row.id)) !== store.getItem("localization.pinRows")) return;
        store.setItem("localization.pins", (store.getItem("localization.pins") || "") + expected + ",");
        store.setItem("localization.pinPhase", "done");
      }
      const settings = document.querySelector("#machines a.machine-name");
      if (settings instanceof HTMLAnchorElement) store.setItem("localization.machinePath", settings.pathname + "/settings");
    }
    await document.fonts.ready;
    if (document.documentElement.scrollWidth > window.innerWidth + 1) throw new Error("Localized route overflows its viewport.");
    store.setItem("localization.routes", (store.getItem("localization.routes") || "") + expected + ":" + route + ",");
    if (routeIndex + 1 < routes.length) { store.setItem("localization.routeIndex", String(routeIndex + 1)); window.location.href = routes[routeIndex + 1]; return; }
    const machine = store.getItem("localization.machinePath");
    store.setItem("localization.phase", machine ? "clone" : "next");
    if (machine) window.location.href = machine;
    return;
  }
  if (store.getItem("localization.phase") === "clone") {
    const machine = store.getItem("localization.machinePath");
    if (path !== machine) { if (machine) window.location.href = machine; return; }
    if (!document.querySelector("[data-phx-main].phx-connected")) return;
    const form = document.querySelector("#clone-form");
    const name = document.querySelector('input[name="clone[name]"]');
    const key = document.querySelector('input[name="clone[request_key]"]');
    if (!(form instanceof HTMLFormElement) || !(name instanceof HTMLInputElement) || !(key instanceof HTMLInputElement)) throw new Error("Clone form is absent.");
    const before = store.getItem("localization.cloneKey");
    if (!before) { store.setItem("localization.cloneKey", key.value); name.value = "mixed-abc-123"; name.dispatchEvent(new Event("input", {bubbles: true})); name.dispatchEvent(new Event("change", {bubbles: true})); return; }
    if (name.value !== "mixed-abc-123" || !window.location.search.includes("mixed-abc-123")) return;
    if (key.value !== before) throw new Error("Clone validation changed its request identity.");
    const locale = document.documentElement.lang;
    store.setItem("localization.clones", (store.getItem("localization.clones") || "") + locale + ",");
    store.removeItem("localization.cloneKey"); store.setItem("localization.phase", "next"); return;
  }
  if (store.getItem("localization.phase") === "next") {
    store.setItem("localization.index", String(Number(store.getItem("localization.index") || "0") + 1));
    store.setItem("localization.phase", "submit");
    store.setItem("localization.pinPhase", "start");
  }
  if (path !== "/settings") { window.location.href = "/settings"; return; }
  const form = document.querySelector("#language-form");
  const select = document.querySelector('#language-form select[name="language[locale]"]');
  if (!(form instanceof HTMLFormElement) || !(select instanceof HTMLSelectElement) || !form.closest(".phx-connected")) return;
  const liveSocket: unknown = Reflect.get(window, "liveSocket");
  if (!(typeof liveSocket === "object" && liveSocket !== null && "isConnected" in liveSocket && typeof liveSocket.isConnected === "function" && liveSocket.isConnected() === true)) return;
  store.setItem("localization.authenticated", "yes");
  const allowed = ["en", "zh-Hans", "hi", "es", "ar", "fr", "bn", "pt-BR", "pt-PT", "ru", "ur", "id", "de", "ja", "pcm", "mr", "te", "tr", "ta", "vi", "ko", "fil", "et", "fi", "sv", "arz", "sw", "ha"];
  const index = Number(store.getItem("localization.index") || "0");
  const phase = store.getItem("localization.phase") || "submit";
  const expected = allowed[index];
  if (expected) {
    if (phase === "submit") {
      if (!Array.from(select.options).some((option) => option.value === expected)) throw new Error("Required locale option is missing.");
      store.setItem("localization.phase", "ready");
      document.documentElement.dataset.localizationSubmitted = "yes";
      form.addEventListener("submit", () => store.setItem("localization.phase", "observe"), {once: true});
      select.value = expected;
      select.dispatchEvent(new Event("change", { bubbles: true }));
      const save = document.querySelector("#save-language");
      if (!(save instanceof HTMLButtonElement)) throw new Error("Save language control is absent.");
      save.scrollIntoView({ block: "center" });
      return;
    }
    if (phase === "ready" || (phase === "observe" && document.documentElement.dataset.localizationSubmitted === "yes")) return;
    if (document.documentElement.lang !== expected || select.value !== expected || !document.querySelector("#clear-language")) return;
    const direction = ["ar", "ur", "arz"].includes(expected) ? "rtl" : "ltr";
    if (document.documentElement.dir !== direction) throw new Error("Saved locale direction mismatches.");
    if (phase === "observe") {
      store.setItem("localization.covered", (store.getItem("localization.covered") || "") + expected + ",");
      store.setItem("localization.phase", "reload");
      window.location.reload();
      return;
    }
    if (phase === "reload") {
      if (store.getItem("localization.repeatRequested") === "yes" && index === 0) store.setItem("localization.repeatVerified", "yes");
      store.setItem("localization.reloaded", (store.getItem("localization.reloaded") || "") + expected + ",");
      store.setItem("localization.phase", "matrix");
      store.setItem("localization.matrixIndex", "0");
      return;
    }
    const matrixIndex = Number(store.getItem("localization.matrixIndex") || "0");
    const width = matrixIndex % 2 === 0 ? 390 : 1440;
    const theme = matrixIndex < 2 ? "light" : "dark";
    if (window.innerWidth !== width || window.innerHeight !== (width === 390 ? 844 : 1000)) return;
    const appearance = document.querySelector("select[data-appearance]");
    if (!(appearance instanceof HTMLSelectElement)) throw new Error("Appearance selector is absent.");
    if (document.documentElement.dataset.theme !== theme || appearance.value !== theme) {
      appearance.value = theme;
      appearance.dispatchEvent(new Event("change", { bubbles: true }));
      return;
    }
    await document.fonts.ready;
    const style = window.getComputedStyle(document.documentElement);
    if (style.colorScheme !== theme || style.getPropertyValue("--background-color").trim() !== (theme === "dark" ? "#000" : "#fff")) throw new Error("Appearance did not apply its theme tokens.");
    if (document.documentElement.scrollWidth > window.innerWidth + 1) throw new Error("Locale presentation overflows its viewport.");
    if (["ar", "arz", "ur"].includes(expected)) {
      const profile = document.querySelector("#profile-account");
      if (!profile || !/[A-Za-z0-9._+-]+@[A-Za-z0-9.-]+/.test(profile.textContent || "")) throw new Error("RTL profile lost its mixed Latin email data.");
      store.setItem("localization.rtlMixedData", (store.getItem("localization.rtlMixedData") || "") + expected + ",");
    }
    store.setItem("localization.matrix", (store.getItem("localization.matrix") || "") + expected + ":" + theme + ":" + width + ",");
    if (matrixIndex < 3) {
      store.setItem("localization.matrixIndex", String(matrixIndex + 1));
      return;
    }
    store.setItem("localization.matrixIndex", "0");
    if (index === 0 && !store.getItem("localization.repeatRequested")) {
      store.setItem("localization.repeatRequested", "yes");
      store.setItem("localization.phase", "submit");
      window.location.hash = "profile";
      return;
    }
    store.setItem("localization.routeIndex", "0");
    store.setItem("localization.phase", "routes");
    window.location.href = "/overview";
    return;
  }
  if (phase === "submit") {
    const reset = document.querySelector("#clear-language");
    if (!(reset instanceof HTMLButtonElement)) throw new Error("Saved override reset control is absent.");
    store.setItem("localization.phase", "resetObserve"); reset.click(); return;
  }
  // Launcher supplies Accept-Language: ja-JP,ja;q=0.9,en;q=0.5.
  if (document.documentElement.lang !== "ja" || document.documentElement.dir !== "ltr" || document.querySelector("#clear-language")) return;
  if (phase === "resetObserve") { store.setItem("localization.phase", "resetReload"); window.location.reload(); return; }
  store.setItem("localization.resetVerified", "yes");
  store.setItem("localization.completed", "yes");
});
// Exactly one admissible action prevents random navigation from racing auth,
// locale persistence, or reload. Every observation is subsequently trace-audited.
export const deterministicLocalization = actions(() => presentation.current.authenticatedSettings && !presentation.current.routePhase && (presentation.current.width !== presentation.current.desiredWidth || presentation.current.height !== presentation.current.desiredHeight)
  ? [{ SetViewport: { width: presentation.current.desiredWidth, height: presentation.current.desiredWidth === 390 ? 844 : 1000 } }]
  : presentation.current.phase === "ready"
    ? [{ Click: { fingerprint: {testId: null, id: "save-language", role: null, accessibleName: null, tag: "button", href: null, nameAttr: null, placeholder: null, inputType: "submit", textContent: null, structuralPath: null}, point: presentation.current.savePoint } }]
    : [advance()]);
