#!/bin/bash
# Creates a new virtual desktop at the end in KDE Plasma 6

set -e

COUNT=$(qdbus6 org.kde.KWin /VirtualDesktopManager count)
qdbus6 org.kde.KWin /VirtualDesktopManager createDesktop "$COUNT" ""
