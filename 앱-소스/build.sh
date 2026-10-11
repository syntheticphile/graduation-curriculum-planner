#!/bin/zsh
# 앱 다시 만들기: 터미널에서  zsh 앱-소스/build.sh
set -e
cd "$(dirname "$0")/.."
SRC="앱-소스"
APP="졸업 커리큘럼 플래너.app"
BUILD="$(mktemp -d)"

echo "▶ 아이콘 생성"
swift "$SRC/makeicon.swift" "$BUILD/icon.png"
mkdir -p "$BUILD/AppIcon.iconset"
for s in 16 32 128 256 512; do
  sips -z $s $s "$BUILD/icon.png" --out "$BUILD/AppIcon.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s*2))
  sips -z $d $d "$BUILD/icon.png" --out "$BUILD/AppIcon.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns "$BUILD/AppIcon.iconset" -o "$BUILD/AppIcon.icns"
# 웹(아이폰 홈 화면)용 아이콘
mkdir -p docs
for s in 180 192 512; do sips -z $s $s "$BUILD/icon.png" --out "docs/icon-$s.png" >/dev/null; done

echo "▶ 컴파일"
swiftc -O -framework Cocoa -framework WebKit "$SRC/main.swift" -o "$BUILD/CurriculumPlanner"

echo "▶ 앱 번들 구성"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BUILD/CurriculumPlanner" "$APP/Contents/MacOS/"
cp "$SRC/Info.plist" "$APP/Contents/"
cp "$BUILD/AppIcon.icns" "$APP/Contents/Resources/"
cp "커리큘럼플래너.html" "$APP/Contents/Resources/index.html"
cp "커리큘럼플래너.html" "docs/index.html"    # 웹(GitHub Pages)용 복사본
codesign --force --deep --sign - "$APP" >/dev/null 2>&1 || true
rm -rf "$BUILD"
echo "✅ 완료: $APP"
