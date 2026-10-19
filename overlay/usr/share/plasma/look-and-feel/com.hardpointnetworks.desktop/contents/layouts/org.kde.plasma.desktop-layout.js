/* HardPoint OS default desktop: a Windows 11 style taskbar.
 * Bottom bar, Start button and pinned/running apps centred, then the system tray
 * (Wi-Fi, sound, battery, notifications), a two-line clock and "show desktop" on the right. */
/*global Panel, gridUnit, desktopsForActivity, currentActivity, applicationExists */

function launcher (id) { return applicationExists(id) ? 'applications:' + id + '.desktop' : null; }

const panel = new Panel;
panel.location = 'bottom';
panel.floating = 0;
panel.hiding = 'normal';
panel.height = Math.round(gridUnit * 2.6);
panel.lengthMode = 'fill';

panel.addWidget('org.kde.plasma.panelspacer');

const start = panel.addWidget('org.kde.plasma.kickoff');
start.currentConfigGroup = ['Shortcuts'];
start.writeConfig('global', 'Alt+F1');
start.currentConfigGroup = ['General'];
start.writeConfig('icon', 'hardpoint');
start.writeConfig('showAppsByName', 'true');
start.writeConfig('paneSwap', 'false');
start.writeConfig('applicationsDisplay', 0);
start.writeConfig('favoritesDisplay', 0);
start.writeConfig('primaryActions', 1);
start.writeConfig('showActionButtonCaptions', 'false');

const tasks = panel.addWidget('org.kde.plasma.icontasks');
tasks.currentConfigGroup = ['General'];
tasks.writeConfig('fill', 'false');
tasks.writeConfig('iconSpacing', 2);
tasks.writeConfig('maxStripes', 1);
tasks.writeConfig('showOnlyCurrentDesktop', 'false');
tasks.writeConfig('launchers', [
    'applications:org.kde.dolphin.desktop',
    launcher('microsoft-edge') || 'preferred://browser',
    launcher('hardpoint-setup'),
    'applications:org.kde.konsole.desktop',
    launcher('code')
].filter(function (x) { return x; }));

panel.addWidget('org.kde.plasma.panelspacer');

const tray = panel.addWidget('org.kde.plasma.systemtray');
tray.currentConfigGroup = ['Shortcuts'];
tray.writeConfig('global', 'Meta+A');          // quick settings: Wi-Fi, sound, battery, Bluetooth

const clock = panel.addWidget('org.kde.plasma.digitalclock');
clock.currentConfigGroup = ['Appearance'];
clock.writeConfig('showDate', 'true');
clock.writeConfig('dateDisplayFormat', 'BelowTime');
clock.writeConfig('dateFormat', 'shortDate');
clock.writeConfig('showSeconds', 'Never');
clock.writeConfig('autoFontAndSize', 'true');
clock.currentConfigGroup = ['Shortcuts'];
clock.writeConfig('global', 'Meta+N');         // calendar

panel.addWidget('org.kde.plasma.showdesktop');

// HardPoint wallpaper (light/dark variants follow the colour scheme)
const desktops = desktopsForActivity(currentActivity());
for (let i = 0; i < desktops.length; i++) {
    const d = desktops[i];
    d.wallpaperPlugin = 'org.kde.image';
    d.currentConfigGroup = ['Wallpaper', 'org.kde.image', 'General'];
    d.writeConfig('Image', 'file:///usr/share/wallpapers/HardPoint/');
    d.writeConfig('FillMode', 2);
}
