/*global loadTemplate, desktopsForActivity, currentActivity, getApiVersion */

//== BEGIN activateWallpaperFn {
// Use standard wallpaper update from org.breeze.kde.
// Also enable dynamic day-night Kubuntu Wallpaper theme.
function activateWallpaperFn ( desktop_list ) {
  for ( let idx = 0; idx < desktop_list.length; idx++ ) {
    const desktop_obj = desktop_list[idx];
    desktop_list[idx].wallpaperPlugin = 'org.kde.image';
    desktop_obj.currentConfigGroup = [ 'Wallpaper', 'org.kde.image', 'General' ];
    desktop_obj.writeConfig( 'Image', 'file:///usr/share/wallpapers/Kubuntu' );
    desktop_obj.writeConfig( 'DynamicMode', 0 );
  }
}
//== END activateWallpaperFn }

// THESE ARE DISABLED PER KDE BUG 512005.
// They do not work, see notes in mainFn for more details.
// Add globals gridUnit, screenGeometry */
//
//== BEGIN addDesktopIconsFn {
// function addDesktopIconsFn ( desktop_obj ) {
//   const
//     screen_obj   = screenGeometry(0),
//     margin_px    = gridUnit * 2,
//     size_px      = gridUnit * 6,
//     x_px         = screen_obj.width - size_px - margin_px,
//     y1_px        = margin_px,
//     y2_px        = size_px + margin_px * 2,
//     link_matrix  = [
//       { path: '/usr/share/applications/org.kubuntu.web.home.desktop',
//         x: x_px, y: y1_px
//       },
//       { path: '/usr/share/applications/org.kfocus.web.howtos.desktop',
//         x: x_px, y: y2_px
//       }
//     ];
//
//   for ( let idx = 0; idx < link_matrix.length; idx++ ) {
//     const link_map = link_matrix[ idx ],
//       icon_obj = desktop_obj.addWidget(
//         'org.kde.plasma.icon',
//         link_map.x, link_map.y, size_px, size_px
//       );
//     // This matches serialize dump and avoids hundreds of copies in .local
//     icon_obj.writeConfig( 'localPath', link_map.path );
//     icon_obj.currentConfigGroup = [ 'General' ];
//     icon_obj.writeConfig( 'url', 'file://' + link_map.path );
//   }
// }
//== . END addDesktopIconsFn }

//== BEGIN refreshPanelsFn {
// function refreshPanelsFn ( panel_list ) {
//   // Attempt to ensure all that any panels are screen 0 (not -1)
//   for ( let idx = 0; idx < panel_list.length; idx++ ) {
//     const panel_obj = panel_list[idx];
//     panel_obj.writeConfig('dummyInit', true );
//     panel_list[idx].reloadConfig();
//   }
// }
//== . END refreshPanelsFn }

//== BEGIN mainFn {
function mainFn () {
  // This returns true; no panel_obj is returned as one might expect
  loadTemplate( 'org.kubuntu.desktop.defaultPanel' );

  const desktop_list = desktopsForActivity(currentActivity());
  activateWallpaperFn( desktop_list );

  // DISABLED per bug https://bugs.kde.org/show_bug.cgi?id=512005#c14
  // Adding icons pushes the panel to desktop -1, and there is no easy way
  // around this. One may be able to run a shell update script to reload
  // icons on every refresh, but this would have to be marked as not finished
  // at the beginning of each run and also recognize the desktop theme.
  //
  // main_desktop_obj = desktop_list[0];
  // addDesktopIconsFn( main_desktop_obj );
  //
  // "Wake up" any panels that might have been push to desktop -1
  // const panel_list = panels();
  // refreshPanelsFn( panel_list );

  return true;
}
//== . END mainFn }

// This is recommended at the opening of any layout.js.
const plasma_obj = getApiVersion(1);
mainFn();

