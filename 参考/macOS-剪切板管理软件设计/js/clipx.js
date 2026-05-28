(function () {
  var ICONS = {
    clipboard: '<path d="M9 4h6"/><path d="M9 4a3 3 0 0 1 6 0"/><path d="M8 5H6a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2"/><path d="M9 9h6"/><path d="M8 13h8"/><path d="M8 17h5"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m16.5 16.5 3.5 3.5"/>',
    text: '<path d="M5 6h14"/><path d="M8 6v12"/><path d="M16 6v12"/><path d="M7 18h4"/><path d="M13 18h4"/>',
    link: '<path d="M10 13a5 5 0 0 0 7.1 0l1.4-1.4a5 5 0 0 0-7.1-7.1L10.5 5.4"/><path d="M14 11a5 5 0 0 0-7.1 0l-1.4 1.4a5 5 0 0 0 7.1 7.1l.9-.9"/>',
    image: '<rect x="4" y="5" width="16" height="14" rx="3"/><circle cx="9" cy="10" r="1.5"/><path d="m7 17 4-4 3 3 2-2 2 3"/>',
    code: '<path d="m9 8-4 4 4 4"/><path d="m15 8 4 4-4 4"/><path d="m13 6-2 12"/>',
    keyboard: '<rect x="3" y="6" width="18" height="12" rx="2"/><path d="M7 10h.01"/><path d="M11 10h.01"/><path d="M15 10h.01"/><path d="M17 14h.01"/><path d="M7 14h6"/>',
    color: '<path d="M12 3v18"/><path d="M12 3a9 9 0 1 1 0 18"/><path d="M12 7h4"/><path d="M12 12h7"/><path d="M12 17h4"/>',
    file: '<path d="M6 3h8l4 4v14H6z"/><path d="M14 3v5h5"/><path d="M9 13h6"/><path d="M9 17h4"/>',
    star: '<path d="m12 3 2.9 5.9 6.5.9-4.7 4.6 1.1 6.5L12 17.8 6.2 21l1.1-6.5-4.7-4.6 6.5-.9z"/>',
    pin: '<path d="m14 4 6 6-4 1-4 7-2-2 7-4 1-4-6-6z"/><path d="m8 16-4 4"/>',
    trash: '<path d="M4 7h16"/><path d="M10 11v6"/><path d="M14 11v6"/><path d="M6 7l1 14h10l1-14"/><path d="M9 7V4h6v3"/>',
    settings: '<path d="M12 8a4 4 0 1 0 0 8 4 4 0 0 0 0-8z"/><path d="M4.9 9.3 3.7 7l2.1-2.1 2.3 1.2"/><path d="M15.9 6.1 18.2 5 20.3 7l-1.2 2.3"/><path d="m19.1 14.7 1.2 2.3-2.1 2.1-2.3-1.2"/><path d="M8.1 17.9 5.8 19 3.7 17l1.2-2.3"/>',
    copy: '<rect x="8" y="8" width="11" height="11" rx="2"/><rect x="5" y="5" width="11" height="11" rx="2"/>',
    paste: '<path d="M9 4h6"/><path d="M9 4a3 3 0 0 1 6 0"/><path d="M8 5H6a2 2 0 0 0-2 2v11a2 2 0 0 0 2 2h5"/><path d="M16 15h5"/><path d="m18.5 12.5 2.5 2.5-2.5 2.5"/>',
    plus: '<path d="M12 5v14"/><path d="M5 12h14"/>',
    more: '<circle cx="5" cy="12" r="1.5"/><circle cx="12" cy="12" r="1.5"/><circle cx="19" cy="12" r="1.5"/>',
    lock: '<rect x="5" y="10" width="14" height="10" rx="2"/><path d="M8 10V7a4 4 0 0 1 8 0v3"/><path d="M12 14v2"/>',
    check: '<path d="m5 12 4 4L19 6"/>',
    moon: '<path d="M20 14.5A8.5 8.5 0 0 1 9.5 4 8.5 8.5 0 1 0 20 14.5z"/>',
    sun: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.9 4.9 1.4 1.4"/><path d="m17.7 17.7 1.4 1.4"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m4.9 19.1 1.4-1.4"/><path d="m17.7 6.3 1.4-1.4"/>',
    arrow: '<path d="M5 12h14"/><path d="m13 6 6 6-6 6"/>',
    back: '<path d="M19 12H5"/><path d="m11 6-6 6 6 6"/>',
    finder: '<path d="M5 4h14v16H5z"/><path d="M12 4v16"/><path d="M8 9h.01"/><path d="M16 9h.01"/><path d="M8 15c2 1.4 6 1.4 8 0"/>'
  };

  function injectIcons() {
    document.querySelectorAll("[data-icon]").forEach(function (el) {
      var name = el.getAttribute("data-icon");
      if (!ICONS[name]) return;
      el.classList.add("icon");
      el.innerHTML = '<svg viewBox="0 0 24 24" fill="none" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + ICONS[name] + "</svg>";
    });
  }

  function setTheme(theme) {
    document.documentElement.setAttribute("data-theme", theme);
    try { localStorage.setItem("clipx-theme", theme); } catch (_) {}
    document.querySelectorAll("[data-theme-toggle]").forEach(function (btn) {
      btn.setAttribute("aria-pressed", theme === "light" ? "true" : "false");
      var label = theme === "light" ? "Light" : "Dark";
      btn.setAttribute("aria-label", "Switch theme, current " + label);
      var text = btn.querySelector("[data-theme-label]");
      if (text) text.textContent = label;
      var icon = btn.querySelector("[data-theme-icon]");
      if (icon) {
        icon.setAttribute("data-icon", theme === "light" ? "sun" : "moon");
        icon.innerHTML = "";
      }
    });
    injectIcons();
  }

  function initTheme() {
    var saved = "dark";
    try { saved = localStorage.getItem("clipx-theme") || "dark"; } catch (_) {}
    setTheme(saved);
    document.querySelectorAll("[data-theme-toggle]").forEach(function (btn) {
      btn.addEventListener("click", function () {
        setTheme(document.documentElement.getAttribute("data-theme") === "light" ? "dark" : "light");
      });
    });
  }

  function showToast(message, iconName) {
    var host = document.querySelector(".toast-host");
    if (!host) {
      host = document.createElement("div");
      host.className = "toast-host";
      document.body.appendChild(host);
    }
    var toast = document.createElement("div");
    toast.className = "toast";
    toast.innerHTML = '<span data-icon="' + (iconName || "check") + '"></span><span>' + message + "</span>";
    host.appendChild(toast);
    injectIcons();
    requestAnimationFrame(function () { toast.classList.add("is-visible"); });
    window.setTimeout(function () {
      toast.classList.remove("is-visible");
      window.setTimeout(function () { toast.remove(); }, 220);
    }, 2200);
  }

  function initFiltering() {
    document.querySelectorAll("[data-filter-input]").forEach(function (input) {
      var target = input.getAttribute("data-filter-input");
      var rows = Array.prototype.slice.call(document.querySelectorAll('[data-filter-item="' + target + '"]'));
      var empty = document.querySelector('[data-empty-for="' + target + '"]');
      function filter() {
        var q = input.value.trim().toLowerCase();
        var visible = 0;
        rows.forEach(function (row) {
          var match = (row.getAttribute("data-search") || row.textContent).toLowerCase().indexOf(q) !== -1;
          row.hidden = !match;
          if (match) visible += 1;
        });
        if (empty) empty.hidden = visible !== 0;
      }
      input.addEventListener("input", filter);
      filter();
    });
  }

  function initRows() {
    document.addEventListener("click", function (event) {
      var action = event.target.closest("[data-action]");
      if (!action) return;
      var type = action.getAttribute("data-action");
      var row = action.closest("[data-row]");
      if (type === "favorite") {
        action.classList.toggle("is-active");
        action.style.color = action.classList.contains("is-active") ? "var(--amber)" : "";
        showToast(action.classList.contains("is-active") ? "Added to favorites" : "Removed from favorites", "star");
      }
      if (type === "delete" && row) {
        row.classList.add("is-removing");
        window.setTimeout(function () { row.remove(); }, 180);
        showToast("Clipboard item deleted", "trash");
      }
      if (type === "delete" && !row) {
        showToast("Selected item deleted", "trash");
      }
      if (type === "copy") {
        var text = action.getAttribute("data-copy") || "Copied from ClipX";
        if (navigator.clipboard && navigator.clipboard.writeText) {
          navigator.clipboard.writeText(text).catch(function () {});
        }
        showToast("Copied again", "copy");
      }
      if (type === "paste") {
        showToast("Ready to paste in the front app", "paste");
      }
      if (type === "pin") {
        showToast("Pinned to the top", "pin");
      }
      if (type === "menu") {
        var menu = action.parentElement.querySelector(".context-menu");
        if (menu) menu.hidden = !menu.hidden;
      }
      if (type === "download") {
        showToast("Download starts when a build is connected", "arrow");
      }
    });

    document.querySelectorAll("[data-row]").forEach(function (row) {
      row.addEventListener("click", function (event) {
        if (event.target.closest("button")) return;
        var group = row.parentElement;
        if (!group) return;
        group.querySelectorAll("[data-row]").forEach(function (item) { item.classList.remove("is-selected"); });
        row.classList.add("is-selected");
      });
      row.addEventListener("keydown", function (event) {
        if (event.target.closest("button")) return;
        if (event.key === "Enter" || event.key === " ") {
          event.preventDefault();
          row.click();
        }
      });
    });
  }

  function initLauncher() {
    var list = document.querySelector("[data-launcher-list]");
    var input = document.querySelector("[data-launcher-input]");
    if (!list || !input) return;
    var rows = Array.prototype.slice.call(list.querySelectorAll("[data-row]"));
    var selected = Math.max(0, rows.findIndex(function (row) { return row.classList.contains("is-selected"); }));

    function visibleRows() {
      return rows.filter(function (row) { return !row.hidden; });
    }

    function paint() {
      visibleRows().forEach(function (row, index) {
        row.classList.toggle("is-selected", index === selected);
      });
    }

    input.addEventListener("input", function () {
      var q = input.value.trim().toLowerCase();
      rows.forEach(function (row) {
        row.hidden = (row.getAttribute("data-search") || row.textContent).toLowerCase().indexOf(q) === -1;
      });
      selected = 0;
      paint();
    });

    input.addEventListener("keydown", function (event) {
      var visible = visibleRows();
      if (!visible.length) return;
      if (event.key === "ArrowDown") {
        event.preventDefault();
        selected = Math.min(visible.length - 1, selected + 1);
        paint();
      }
      if (event.key === "ArrowUp") {
        event.preventDefault();
        selected = Math.max(0, selected - 1);
        paint();
      }
      if (event.key === "Enter") {
        event.preventDefault();
        showToast("Pasted selected item", "paste");
      }
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "f") {
        event.preventDefault();
        showToast("Saved selected result to favorites", "star");
      }
    });

    paint();
    input.focus({ preventScroll: true });
  }

  function initSwitches() {
    document.querySelectorAll(".switch").forEach(function (btn) {
      btn.addEventListener("click", function () {
        var next = btn.getAttribute("aria-pressed") !== "true";
        btn.setAttribute("aria-pressed", String(next));
        showToast(next ? "Setting enabled" : "Setting disabled", "check");
      });
    });
  }

  document.addEventListener("click", function (event) {
    if (!event.target.closest(".context-wrap")) {
      document.querySelectorAll(".context-menu").forEach(function (menu) { menu.hidden = true; });
    }
  });

  document.addEventListener("DOMContentLoaded", function () {
    injectIcons();
    initTheme();
    initFiltering();
    initRows();
    initLauncher();
    initSwitches();
  });
})();
