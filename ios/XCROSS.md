# Compilar VIDA para iOS con xcross (Linux / Fedora)

Guía para generar el `.ipa` de release sin Mac usando [xcross](https://github.com/arxdeus/xcross).
Probado hasta el paso de "Building Flutter plugins (Swift Package Manager)" en Windows;
en Linux aplica lo mismo.

## Requisitos

| Herramienta | Versión | Notas |
|---|---|---|
| xcross | 2.0.6 **parchado** (ver paso 2) | El release oficial falla con Firebase |
| Flutter | **3.47.6** exacto | Es la última versión con compilador AOT publicado para xcross (`xcross flutter doctor` lo confirma) |
| Swift | 6.4 o superior | `swiftly` en Fedora |
| LLVM | 20+ con `ld64.lld` | `sudo dnf install llvm lld clang` |
| SDK de iOS | `xcross sdk install Xcode_27.1.xip` | Xcode 26+ para que Liquid Glass compile |
| iPhone | iOS 17+ | Solo para instalar/ejecutar |

## 1. Flutter 3.47.6

```bash
git -C ~/flutter fetch --tags
git -C ~/flutter checkout 3.47.6
flutter --version   # Flutter 3.47.6 • Dart 3.13.5
```

No uses `flutter upgrade` hasta que xcross publique compilador para una versión más nueva
(`gh release list -R arxdeus/xcross_gen_snapshot`).

## 2. Parchar xcross (obligatorio con Firebase)

`firebase-ios-sdk` arrastra `swift-protobuf`, cuyo plugin de build se compila para el
**host** (Linux/Windows), no para iOS. xcross 2.0.6 encuentra ese `-Swift.h` fuera de la
carpeta de iOS y aborta con:

```
Cannot read planned Swift interop headers from …/description.json: FormatException: Invalid generated header path
```

El parche `tool/xcross-plan-reader.patch` hace que ignore esos headers del host:

```bash
git clone --depth 1 --branch v2.0.6 https://github.com/arxdeus/xcross.git ~/xcross-src
cd ~/xcross-src
git apply /ruta/a/vida_project/tool/xcross-plan-reader.patch
dart pub get
cd packages/xcross
dart run tool/build_xcross.dart
```

El resultado queda en `packages/xcross/build/cli/linux_x64/bundle/` (`bin/` y `lib/`).
Cópialo encima de tu instalación actual:

```bash
XCROSS_HOME="$(dirname "$(dirname "$(readlink -f "$(which xcross)")")")"
cp -r build/cli/linux_x64/bundle/bin/* "$XCROSS_HOME/bin/"
cp -r build/cli/linux_x64/bundle/lib/* "$XCROSS_HOME/lib/"
xcross --version   # debe decir "unreleased"
```

Para volver al oficial: `xcross update --force`.

## 3. Firmar e instalar

```bash
xcross auth --apple-id tu@correo.com   # cuenta gratuita sirve
sudo xcross tunnel                     # con el iPhone conectado por USB, una vez por conexión
```

## 4. Compilar

Desde la raíz del proyecto:

```bash
flutter pub get
xcross flutter doctor                  # todo en ✓ salvo el dispositivo si no está conectado
xcross flutter build --release --ipa
```

La primera vez tarda ~10 min descargando `firebase-ios-sdk` por SwiftPM.

## Lo que ya está resuelto en el repo

- **Íconos**: sin canal alpha, más PNG sueltos `ios/Runner/AppIcon*.png` declarados en
  `CFBundleIcons` del `Info.plist`, por si la build no genera `Assets.car`.
  Regenerar con `python tool/fix_ios_icons.py`.
- **FlutterFire** (`firebase_core`, `cloud_firestore`, `firebase_auth`,
  `firebase_crashlytics`, `firebase_analytics`): copias en `third_party/` con el
  `Package.swift` de iOS corregido. El original usa `URL(string: #file)` (falla en Windows)
  y lee `../../pubspec.yaml`, que xcross no copia porque solo prepara la carpeta `ios/`.
  Regenerar con `python tool/vendor_flutterfire_ios.py` si se actualizan las versiones.
- **`path_provider_foundation` fijado en 2.5.1**: la 2.6.0 usa `objective_c` con native
  assets y xcross no tiene `strip` en su `xcrun`.
- **Swift Package Manager** activado en `pubspec.yaml` (`enable-swift-package-manager`);
  xcross no soporta CocoaPods.
- **Deployment target iOS 15.0** (lo exige `cupertino_native_ui`).

## Limitaciones conocidas

- **`home_widget`** solo trae podspec de CocoaPods: xcross lo omite, así que los widgets de
  pantalla de inicio de iOS (`ios/VidaWidgets/`) no se incluyen. Por eso
  `PlatformCaps.homeWidgets` es `false` en iOS (oculta Contra pecado / Widget favorito y
  evita `MissingPluginException`). Si algún día se compila con Xcode en una Mac, se puede
  volver a activar quitando la condición de iOS en `lib/utils/platform_caps.dart`.
- No se generan dSYM si `dsymutil` viene de un toolchain de Swift con asserts; no afecta al `.ipa`.
