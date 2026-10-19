# Kubuntu Logo Branding Details
Last updated 2024-04-15 mmikowski

## Source
See throbber.xcf for source files. This replaces kglow.xcf which had the glow
style from prior releases.

## Animation files
These are named throbber-00xx.png and play around 50 fps. We use a sinosoidal
glow effect updated to the latest Noble branding. These can be edited in Gimp.

Previously, there was a set of files called animation-00xx.png. These have
been removed as their content is deprecated and does not appear used anywhere.

## Previewing
To preview the animation, use the following technique:

```bash
# Backup existing theme
cd /usr/share/plymouth/themes
sudo cp -a kubuntu-logo kubuntu-logo.O

# Now merge your changes to the theme in kubuntu-logo
meld ~/Github/kubuntu-settings/plymouth/kubuntu-logo \
  /usr/share/plymouth/themes/kubuntu-logo

# Now preview here
sudo pkill plymouthd
sudo plymouthd --tty tty3
sudo plymouth show-splash
```

Important: You can plymouth-x11 to test a display, but it doesn't show the
animation. We found this technique more representative and faster without the
need to add plymouth-x11. See [docs here][_00100].

## Testing
Once the directory is merged, you can reboot to ensure the entire process
works as expected.

## End

[_00100]:https://antumdeluge.wordpress.com/2016/04/06/plymouth-bootsplash/
