#!/bin/bash
# Скрипт автоматической сборки MacLngSwitcher

set -e

# Переходим в каталог скрипта
cd "$(dirname "$0")"

echo "=== Сборка MacLngSwitcher ==="

# 1. Очистка и создание структуры
echo "1. Подготовка структуры..."
rm -rf build MacLngSwitcher.app
mkdir -p build
mkdir -p MacLngSwitcher.app/Contents/MacOS
mkdir -p MacLngSwitcher.app/Contents/Resources

# 2. Генерация иконок
echo "2. Генерация иконки приложения..."
mkdir -p build/AppIcon.iconset
swift scripts/generate_icon.swift build/icon_master.png

# Нарезаем мастер-картинку на размеры для .icns
sips -z 16 16     build/icon_master.png --out build/AppIcon.iconset/icon_16x16.png
sips -z 32 32     build/icon_master.png --out build/AppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     build/icon_master.png --out build/AppIcon.iconset/icon_32x32.png
sips -z 64 64     build/icon_master.png --out build/AppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   build/icon_master.png --out build/AppIcon.iconset/icon_128x128.png
sips -z 256 256   build/icon_master.png --out build/AppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   build/icon_master.png --out build/AppIcon.iconset/icon_256x256.png
sips -z 512 512   build/icon_master.png --out build/AppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   build/icon_master.png --out build/AppIcon.iconset/icon_512x512.png
sips -z 1024 1024 build/icon_master.png --out build/AppIcon.iconset/icon_512x512@2x.png

# Создаем .icns файл
iconutil -c icns build/AppIcon.iconset -o MacLngSwitcher.app/Contents/Resources/AppIcon.icns

# 3. Копирование Info.plist
echo "3. Установка Info.plist..."
cp Resources/Info.plist MacLngSwitcher.app/Contents/Info.plist

# 4. Компиляция исходного кода Swift
echo "4. Компиляция исходных файлов..."
ARCH=$(uname -m)
SDK_PATH=$(xcrun --show-sdk-path --sdk macosx)

# Собираем все .swift файлы в Sources
swiftc Sources/*.swift \
    -o MacLngSwitcher.app/Contents/MacOS/MacLngSwitcher \
    -target ${ARCH}-apple-macos13.0 \
    -sdk ${SDK_PATH} \
    -O

echo "=== Сборка успешно завершена! ==="
echo "Вы можете запустить приложение командой: open MacLngSwitcher.app"
