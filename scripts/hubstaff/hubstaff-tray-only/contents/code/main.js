// Hubstaff Tray Only
// Permanently hides Hubstaff from the taskbar and pager.
// kdocker handles show/hide via the system tray icon.

function manageHubstaffWindow(window) {
    if (!window) return;

    var title = window.caption || "";
    var resourceClass = window.resourceClass || "";
    var resourceName = window.resourceName || "";

    // Match by title or class (case-insensitive)
    var isHubstaff = title.toLowerCase().indexOf("hubstaff") >= 0
                  || resourceClass.toLowerCase().indexOf("hubstaff") >= 0
                  || resourceName.toLowerCase().indexOf("hubstaff") >= 0;

    if (!isHubstaff) return;

    // Set once and never change — let kdocker handle visibility
    window.skipTaskbar = true;
    window.skipPager = true;
}

// Hook new windows
workspace.windowAdded.connect(function(window) {
    manageHubstaffWindow(window);
});

// Apply to existing windows
var allWindows = workspace.windows;
for (var i = 0; i < allWindows.length; i++) {
    manageHubstaffWindow(allWindows[i]);
}
