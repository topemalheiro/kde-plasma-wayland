// Create new virtual desktop at the end
function createDesktop() {
    const desktops = workspace.desktops;
    const lastDesktop = desktops[desktops.length - 1];
    workspace.createDesktop(lastDesktop, "");
}

// Remove current virtual desktop
function removeCurrentDesktop() {
    const current = workspace.currentDesktop;
    if (workspace.desktops.length > 1) {
        workspace.removeDesktop(current);
    }
}

// Register global shortcuts
registerShortcut("Create New Virtual Desktop", "Create a new virtual desktop at the end", "Meta+Ctrl+D", createDesktop);
registerShortcut("Remove Current Virtual Desktop", "Remove the current virtual desktop", "Meta+Ctrl+Shift+D", removeCurrentDesktop);
