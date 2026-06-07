import QtQuick 2.15
import QtQuick.Window 2.15
import org.kde.plasma.extras 2.0 as PlasmaExtras

Window {
    width: 400
    height: 300
    visible: true
    title: "Submenu Debug"

    Rectangle {
        anchors.fill: parent
        color: "#2d2d2d"

        Text {
            anchors.centerIn: parent
            text: "Right-click anywhere in this window"
            color: "white"
            font.pointSize: 14
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: testMenu.open(mouse.x, mouse.y)
        }
    }

    PlasmaExtras.Menu {
        id: testMenu

        // Test 1: Inline submenu (the pattern that works in ContextMenu.qml)
        PlasmaExtras.MenuItem {
            id: inlineItem
            text: "Inline Submenu (should work)"
            icon: "folder"
            readonly property PlasmaExtras.Menu subMenu: PlasmaExtras.Menu {
                visualParent: inlineItem.action
                PlasmaExtras.MenuItem {
                    text: "Inline Sub-item 1"
                    onClicked: console.log("inline 1 clicked")
                }
                PlasmaExtras.MenuItem {
                    text: "Inline Sub-item 2"
                    onClicked: console.log("inline 2 clicked")
                }
            }
        }

        // Test 2: Dynamically created submenu with Qt.createQmlObject
        // This is what the patch tried first (parent = menuItem)
        Component.onCompleted: {
            // Test 2a: Menu as child of MenuItem via Qt.createQmlObject
            var item2a = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                    text: "Dyn QO parent=menuItem (Test 2a)"
                    icon: "folder"
                }
            `, testMenu);
            var sub2a = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.Menu {}
            `, item2a);
            sub2a.visualParent = item2a.action;
            var subItem2a = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                    text: "Sub-item 2a"
                }
            `, sub2a);
            sub2a.addMenuItem(subItem2a);
            testMenu.addMenuItem(item2a);

            // Test 2b: Menu as readonly property inside Qt.createQmlObject MenuItem
            var item2b = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                    text: "Dyn QO with prop Menu (Test 2b)"
                    icon: "folder"
                    readonly property PlasmaExtras.Menu _subMenu: PlasmaExtras.Menu {
                        visualParent: parent.action
                    }
                }
            `, testMenu);
            var subItem2b = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                    text: "Sub-item 2b"
                }
            `, item2b._subMenu);
            item2b._subMenu.addMenuItem(subItem2b);
            testMenu.addMenuItem(item2b);

            // Test 2c: Using newMenuItem helper from ContextMenu.qml pattern
            var item2c = newMenuItem(testMenu);
            item2c.text = "newMenuItem + newSubMenu (Test 2c)";
            item2c.icon = "folder";
            var sub2c = newSubMenu(item2c);
            sub2c.visualParent = item2c.action;
            var subItem2c = newMenuItem(sub2c);
            subItem2c.text = "Sub-item 2c";
            sub2c.addMenuItem(subItem2c);
            testMenu.addMenuItem(item2c);

            // Test 2d: newMenuItem with inline property via Qt.createQmlObject
            var item2d = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {
                }
            `, testMenu);
            item2d.text = "newMenuItem + prop Menu (Test 2d)";
            item2d.icon = "folder";
            var sub2d = Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.Menu {
                }
            `, item2d);
            sub2d.visualParent = item2d.action;
            var subItem2d = newMenuItem(sub2d);
            subItem2d.text = "Sub-item 2d";
            sub2d.addMenuItem(subItem2d);
            testMenu.addMenuItem(item2d);
        }

        function newMenuItem(parent: QtObject): PlasmaExtras.MenuItem {
            return Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.MenuItem {}
            `, parent) as PlasmaExtras.MenuItem;
        }

        function newSubMenu(parent: QtObject): PlasmaExtras.Menu {
            return Qt.createQmlObject(`
                import org.kde.plasma.extras 2.0 as PlasmaExtras
                PlasmaExtras.Menu {}
            `, parent) as PlasmaExtras.Menu;
        }
    }
}
