#!/system/bin/sh
# Self-mount for root managers whose module mounting is missing or disabled:
# KernelSU / SukiSU / APatch without a mount metamodule.
# On Magisk (or KSU with Magic Mount/OverlayFS metamodule) the overlay is
# already in place when this runs; the content check below makes each
# bind-mount a no-op in that case, so both paths can coexist safely.

MODDIR=$(dirname "$(readlink -f "$0")")
SRC="$MODDIR/system/fonts/NotoColorEmoji.ttf"
[ -f "$SRC" ] || exit 0

mount_font() {
  dst="/system/fonts/$1"
  [ -e "$dst" ] || return 0
  cmp -s "$SRC" "$dst" && return 0
  mount --bind "$SRC" "$dst" 2>/dev/null || mount -o bind "$SRC" "$dst" 2>/dev/null
}

# Same parser as install.sh: emoji (und-Zsye) entries from the font config.
# Android 15+ deprecates fonts.xml in favor of the generated font_fallback.xml;
# try both and use whichever yields results.
FONTS=$(sed -ne '/<family lang="und-Zsye".*>/,/<\/family>/ {s/.*<font weight="400" style="normal">\(.*\)<\/font>.*/\1/p;}' /system/etc/fonts.xml 2>/dev/null)
[ -n "$FONTS" ] || FONTS=$(sed -ne '/<family lang="und-Zsye".*>/,/<\/family>/ {s/.*<font weight="400" style="normal">\(.*\)<\/font>.*/\1/p;}' /system/etc/font_fallback.xml 2>/dev/null)

for f in $FONTS; do
  mount_font "$f"
done

# Report live status in the manager's module list (Zygisk Next style):
# the module is "active" when every emoji font slot currently serves our
# Twemoji file — true both after a successful bind-mount and when the
# manager's own mount already put our file in place.
ok=0
total=0
for f in $FONTS; do
  total=$((total+1))
  cmp -s "$SRC" "/system/fonts/$f" && ok=$((ok+1))
done
if [ "$total" -gt 0 ] && [ "$ok" -eq "$total" ]; then
  STATUS="✅ Twemoji active ($ok/$total emoji fonts)"
elif [ "$ok" -gt 0 ]; then
  STATUS="⚠️ Twemoji partial ($ok/$total emoji fonts)"
else
  STATUS="❌ Twemoji not active"
fi
sed -i "s|^description=.*|description=${STATUS}. Systemless Twemoji on KernelSU/SukiSU/APatch; Magic Mount on Magisk.|" "$MODDIR/module.prop" 2>/dev/null
