const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const logic = vm.createContext({});
for (const file of ["logic.js", "apps.js"]) {
    vm.runInContext(fs.readFileSync(path.join(__dirname, "contents/ui", file), "utf8"), logic, {filename: file});
}
const {entries, findWindow, activate, sectorAt} = logic;
assert.ok(entries.length >= 1 && entries.length <= 9, "Every app must have a keyboard shortcut");
assert.equal(new Set(entries.map(app => app.desktop)).size, entries.length, "No duplicate app slots");
for (const app of entries) {
    assert.ok(app.label && app.desktop.endsWith(".desktop"));
    assert.ok((app.classes || []).every(value => typeof value === "string" && value.trim()));
}

// Clockwise sectors are centered on the icons, including the wrap around north.
const count = entries.length;
for (let i = 0; i < count; ++i) {
    for (const [offset, expected] of [[0, i], [0.5 - 1e-6, i], [0.5 + 1e-6, (i + 1) % count]]) {
        const angle = (i + offset) * 2 * Math.PI / count;
        assert.equal(sectorAt(140 * Math.sin(angle), -140 * Math.cos(angle), count, 80, 204), expected);
    }
}
assert.equal(sectorAt(0, -79.99, count, 80, 204), -1);
assert.equal(sectorAt(0, -80, count, 80, 204), 0);
assert.equal(sectorAt(0, -204, count, 80, 204), 0);
assert.equal(sectorAt(0, -204.01, count, 80, 204), -1);
assert.equal(sectorAt(0, 0, count, 80, 204), -1);
assert.equal(sectorAt(0, -140, 0, 80, 204), -1);

const app = entries[0];
const otherDesktop = {id: "other-desktop"};
const originalDesktop = {id: "current-desktop"};
const existing = {
    normalWindow: true, skipTaskbar: false, minimized: true,
    desktopFileName: `/usr/share/applications/${app.desktop.toUpperCase()}`,
    desktops: [otherDesktop], activities: ["other-activity"]
};
const topmost = {...existing};
assert.equal(findWindow(app, [existing, topmost]), topmost);
assert.equal(findWindow(app, [existing, {...topmost, skipTaskbar: true}, {...topmost, normalWindow: false}]), existing);
assert.equal(findWindow(app, [{...existing, deleted: true}]), null, "Closed windows retained for animations cannot receive focus");
const legacy = {...existing, desktopFileName: "", resourceClass: app.classes[0]};
assert.equal(findWindow(app, [legacy]), legacy);
assert.equal(findWindow(app, [{...legacy, resourceClass: "", resourceName: app.classes[0]}]).resourceName, app.classes[0]);
const pwa = {...existing, desktopFileName: "chrome-separate-web-app-Default", resourceClass: app.classes[0]};
assert.equal(findWindow(app, [pwa]), null, "A browser slot must not select a separate PWA");
assert.equal(findWindow(app, [existing, pwa]), existing);
assert.equal(findWindow(app, [{...legacy, resourceClass: "", resourceName: ""}]), null);

let launches = 0;
const workspace = {
    stackingOrder: [existing], currentDesktop: originalDesktop,
    currentActivity: "current-activity", showingDesktop: true, activeWindow: null
};
assert.equal(activate(app, workspace, () => ++launches), true);
assert.equal(launches, 0, "An existing window must never create another instance");
assert.equal(workspace.activeWindow, existing);
assert.equal(workspace.currentDesktop, otherDesktop);
assert.equal(workspace.currentActivity, "other-activity");
assert.equal(workspace.showingDesktop, false);
assert.equal(existing.minimized, false);

workspace.stackingOrder = [{...existing, desktops: [], activities: []}];
assert.equal(activate(app, workspace, () => ++launches), true);
assert.equal(workspace.currentDesktop, otherDesktop, "All-desktop windows keep the current desktop");
assert.equal(workspace.currentActivity, "other-activity", "All-activity windows keep the current activity");
assert.equal(launches, 0);
workspace.stackingOrder = [pwa];
assert.equal(activate(app, workspace, () => { launches++; return false; }), false);
assert.equal(launches, 1, "Launch once only when the requested app is absent");
console.log("MX Ring checks passed: sectors, app config, focus, minimized windows, desktops, activities, launch fallback, PWA exclusion.");
