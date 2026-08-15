# PowerEMS — Windows Dependency Report

Date: 2026-08-14
Version audited: 1.1.19 (pubspec.yaml)
Build output: `build\windows\x64\runner\Release\`

## 1. Method

- `dumpbin /dependents` (MSVC 14.51, VS Build Tools) run against `ems.exe` and every
  DLL produced by `flutter build windows --release`.
- Legacy `windows/installer.iss` and `windows/PowerEMS.iss` (Inno Setup 6) reviewed.
- App source reviewed for WebView / platform-channel usage.

## 2. Native dependency audit result

| Binary | VC++ Runtime ^ | Windows System DLLs (already in OS) |
|---|---|---|
| `ems.exe` | MSVCP140, VCRUNTIME140, VCRUNTIME140_1 | KERNEL32, USER32, SHELL32, ole32, ADVAPI32, api-ms-win-crt-* (UCRT) |
| `flutter_windows.dll` | — | PSAPI, SHLWAPI, RPCRT4, WINMM, WS2_32, IMM32, OPENGL32, bcrypt, ntdll, GDI32, CRYPT32, UIAutomationCore, OLEACC, PROPSYS, dxgi, d3d9, api-ms-win-core-*; delay-load dwmapi, dbghelp |
| `app_links_plugin.dll` | MSVCP140, VCRUNTIME140, VCRUNTIME140_1 | api-ms-win-crt-* |
| `share_plus_plugin.dll` | MSVCP140, VCRUNTIME140, VCRUNTIME140_1 | api-ms-win-core-winrt-*, api-ms-win-crt-* |
| `url_launcher_windows_plugin.dll` | MSVCP140, VCRUNTIME140, VCRUNTIME140_1 | ADVAPI32, api-ms-win-crt-* |
| `flutter_secure_storage_windows_plugin.dll` | MSVCP140, VCRUNTIME140, VCRUNTIME140_1 | VERSION, bcrypt, api-ms-win-crt-* |
| `webview_flutter_windows_plugin.dll` | MSVCP140, VCRUNTIME140, VCRUNTIME140_1 | SHELL32, ole32, d3d11, api-ms-win-crt-* |
| `flutter_local_notifications_windows.dll` | VCRUNTIME140, VCRUNTIME140_1 | OLEAUT32, api-ms-win-core-winrt-*, api-ms-win-crt-* |
| `dartjni.dll` | — | api-ms-win-crt-* |
| `WebView2Loader.dll` | — | ADVAPI32, ole32 |

^ Only `MSVCP140.dll`, `VCRUNTIME140.dll`, `VCRUNTIME140_1.dll` come from the Visual
C++ Redistributable. Every other import is a Windows 10/11 system DLL (
`api-ms-win-crt-*` is the Universal CRT, always present on modern Windows).

### 2.1 VC++ runtime DLLs required (app-local)

| File | Source |
|---|---|
| `msvcp140.dll` (628 KB) | `C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools\VC\Redist\MSVC\14.29.30133\x64\Microsoft.VC142.CRT` (official Microsoft redistributable folder) |
| `vcruntime140.dll` (174 KB) | same folder |
| `vcruntime140_1.dll` (49 KB) | same folder |

All three are authenticode-verified: **CN=Microsoft Corporation** (Valid).
They are staged into the release directory next to `ems.exe` by `build_windows.bat`
(app-local deployment). Windows loads them from the application directory first,
so a clean PC runs PowerEMS without any Visual C++ Redistributable installation.

## 3. WebView2 — NOT required

- `pubspec.yaml` declares `webview_flutter` / `webview_flutter_windows`.
- Source (`lib/presentation/pages/razorpay_checkout_page.dart`) **explicitly
  excludes Windows/macOS** from the in-app WebView (`supported` returns false;
  desktop falls back to the hosted Razorpay checkout page in the default browser).
- `dumpbin` shows `webview_flutter_windows_plugin.dll` does **not** import
  `MSCoreWebView2.dll`; `WebView2Loader.dll` only imports ADVAPI32/ole32.
- Conclusion: Microsoft Edge WebView2 Runtime is **not** a prerequisite. No
  WebView2 installation/check is included in the installer.

## 4. Other native checks

- **No OpenSSL / networking DLLs** — Supabase client uses pure Dart HTTP/WebSocket.
- **No SQLite / native database DLLs** — sembast is pure Dart.
- **No PDF/printing native DLLs** — `pdf` package is pure Dart.
- **No third-party runtime package** — zero DLLs from unknown sources.

## 5. Installer contents (PowerEMS_Setup_v1.1.19.exe)

```
dist\PowerEMS_Setup_v1.1.19.exe  (12 MB)  installs to C:\Program Files\PowerEMS\
  ems.exe
  flutter_windows.dll
  msvcp140.dll, vcruntime140.dll, vcruntime140_1.dll   (app-local runtime)
  app_links_plugin.dll, dartjni.dll
  flutter_local_notifications_windows.dll
  flutter_secure_storage_windows_plugin.dll
  share_plus_plugin.dll, url_launcher_windows_plugin.dll
  WebView2Loader.dll, webview_flutter_windows_plugin.dll
  data\app.so
  data\icudtl.dat
  data\flutter_assets\  (recursively: .env, fonts, packages, shaders, manifests...)
```

## 6. Clean-PC expectations

On a fresh Windows x64 client without Visual Studio/Flutter/VC++ Redistributable:

1. Run `PowerEMS_Setup_v1.1.19.exe` (admin).
2. Files install to `C:\Program Files\PowerEMS\`.
3. `ems.exe` loads with DLL search order: app directory first →
   `msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll` resolve locally.
4. No VCRUNTIME140.dll / MSVCP140.dll error is expected.
5. Desktop + Start Menu shortcuts created; uninstaller available.

## 6.1 Architecture coverage

- **x64 Windows (10/11)**: native x64 install/run.
- **ARM64 Windows (11, e.g. Surface Pro X, Copilot+ PCs)**: supported —
  `ArchitecturesAllowed=x64compatible` + `ArchitecturesInstallIn64BitMode=x64compatible`
  (Inno Setup 6.2+) install the x64 build in 64-bit mode; Windows' built-in x64
  emulation (Prism) runs `ems.exe` and the app-local runtime DLLs.
- **x86 (32-bit) Windows**: NOT supported. Flutter has no 32-bit Windows target,
  and Windows 11 ships 64-bit only. Inno Setup refuses installation on 32-bit OS
  with its standard architecture message. A separate Flutter Web deployment can
  serve these clients through a browser (project already has `web/` support).

**Remaining prerequisites: none.** No separate installation of Visual C++
Redistributable (or anything else) is required for PowerEMS to launch.

## 7. Rebuild for future releases

```
build_windows.bat
```
performs: version read → clean → pub get → release build → output verification →
runtime DLL staging → dumpbin import check → Inno Setup compile → `dist\PowerEMS_Setup_vX.X.X.exe`.