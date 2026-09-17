function normalize(value) {
    return String(value || "").split("/").pop().replace(/\.desktop$/i, "").toLowerCase();
}

function findWindow(app, windows) {
    const ids = [app.desktop].concat(app.classes || []).map(normalize);
    for (let i = windows.length - 1; i >= 0; --i) {
        const window = windows[i];
        if (window.deleted || !window.normalWindow || window.skipTaskbar) continue;
        const desktop = normalize(window.desktopFileName);
        // A specific desktop identity wins over shared classes (e.g. Chrome web apps).
        if (desktop ? ids.includes(desktop)
                    : [window.resourceClass, window.resourceName].some(value => ids.includes(normalize(value)))) {
            return window;
        }
    }
    return null;
}

function activate(app, workspace, launch) {
    const window = findWindow(app, workspace.stackingOrder);
    if (!window) return launch();
    if (window.activities.length && !window.activities.includes(workspace.currentActivity)) {
        workspace.currentActivity = window.activities[0];
    }
    if (window.desktops.length && !window.desktops.includes(workspace.currentDesktop)) {
        workspace.currentDesktop = window.desktops[0];
    }
    workspace.showingDesktop = false;
    window.minimized = false;
    workspace.activeWindow = window;
    return true;
}

function sectorAt(x, y, count, innerRadius, outerRadius) {
    const distance = Math.hypot(x, y);
    if (distance < innerRadius || distance > outerRadius || count < 1) return -1;
    const angle = (Math.atan2(y, x) + Math.PI / 2 + 2 * Math.PI) % (2 * Math.PI);
    return Math.floor(angle / (2 * Math.PI / count) + 0.5) % count;
}
