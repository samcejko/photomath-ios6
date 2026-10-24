# ShutterCalc for iOS 6

A universal camera math scanner and solver for **jailbroken iOS 5–10** devices (armv7, e.g. iPad 2, iPhone 4S),
with a second build for **64-bit devices with iOS 14–17** (iPhone X and newer: rootless jailbreaks and TrollStore)
that preserves the classic glossy iOS 6 aesthetic.

Point your camera at a printed or handwritten equation, tap scan, and get instant step-by-step mathematical solutions
typeset in crisp LaTeX using `iosMath`.

Because openrouter.ai requires TLS 1.2/1.3 with modern AEAD cipher suites that the legacy iOS 6 networking stack cannot negotiate,
the app embeds its own TLS stack (Mbed TLS) and HTTP client: everything connects directly from your device without any relay server.

## Features

- **Live Camera Scanner**: Viewfinder with animated targeting reticle, tap-to-focus, and flashlight torch toggle (`AVCaptureSession`).
- **Step-by-Step Solutions**: Pedagogical breakdown of every mathematical step, explaining each transformation with high-quality LaTeX formulas.
- **Native LaTeX Rendering**: Embedded `iosMath` typesets formulas (`MTMathUILabel`) directly on iOS 6.
- **Manual Math Keyboard**: Full on-screen math keyboard (fractions $\frac{a}{b}$, powers $x^2$, roots $\sqrt{x}$, parentheses, algebraic variables $x, y$, trigonometry $\sin, \cos, \tan$, logarithms) with real-time LaTeX preview.
- **Dynamic Model Fallback**: Connects to OpenRouter and queries the live models catalog at runtime. Automatically filters for vision-capable models, filters out restrictive content-safety/moderation models, and automatically falls back to subsequent models in the chain if a model fails or rate-limits.
- **History & Offline Review**: Saved equations and solution steps stay on your device for offline studying.
- **Photo Library & Clipboard**: Scan photos directly from your Camera Roll or paste equation text/images from the clipboard.
- **Glossy iOS 6 Design**: Authentic skeuomorphic textures, glossy navigation bars, and custom button styling.
- **Bilingual**: Full English and Czech (`en.lproj` and `cs.lproj`) localization.

## Download

Get the latest packages from the [Releases](../../releases/latest) page:

| Device | Package |
| --- | --- |
| iOS 5–10, 32-bit (iPad 2, iPhone 4S, …) | `ShutterCalc-<version>.ipa` or `com.samcejko.shuttercalc_<version>_iphoneos-arm.deb` |
| iOS 14–17, 64-bit, rootless jailbreak (palera1n, Dopamine) | `com.samcejko.shuttercalc_<version>_iphoneos-arm64.deb` |
| iOS 14–17, 64-bit, TrollStore | `ShutterCalc-<version>-arm64.ipa` |

## Installing on the device

The easy way: add the repository `http://repo.samcejko.eu/` in Cydia (Sources → Edit → Add), Sileo, Zebra or Installer
and install ShutterCalc from there.

By hand:
1. Cydia: **AppSync Unified** (repo `https://cydia.akemi.ai/`) and **IPA Installer Console** (BigBoss).
2. Copy the `.ipa` to the device and run `ipainstaller -f ShutterCalc.ipa`, or install the `.deb` via `dpkg -i` followed by `uicache`.

On iOS 14–17 (64-bit): with a rootless jailbreak install the `iphoneos-arm64` `.deb` with `dpkg -i`; without a jailbreak open the `-arm64.ipa` in [TrollStore](https://github.com/opa334/TrollStore).

## Building (GitHub Actions)

No Mac needed. Every push and pull request runs `.github/workflows/build.yml` on Ubuntu with Theos, Mbed TLS and iosMath:

- `ios5-armv7`: iOS 9.3 SDK, deployment target 5.0 → `ShutterCalc-<version>.ipa` and `.deb`.
- `ios14-arm64`: iOS 16.5 SDK, deployment target 14.0 → `ShutterCalc-<version>-arm64.ipa` and `iphoneos-arm64.deb`.

Local PowerShell helpers (Windows):
```powershell
.\tools\gh-push.ps1 -Message "update"    # push via GitHub REST API
.\tools\gh-build.ps1 -Download -Install  # trigger build, fetch packages, install to device
```

## Project Layout

- `src/Net` – Mbed TLS socket, HTTP client, and OpenRouter client.
- `src/Model` – Dynamic model catalog with content-safety exclusion, fallback resolver, math solution models, and history store.
- `src/Theme` – Skeuomorphic iOS 6 glossy styling, fonts, and custom buttons.
- `src/UI` – Camera scanner, viewfinder overlay, math keyboard, step-by-step solution viewer, history, and settings.
- `src/Util` – iOS 6 / modern iOS compatibility shims (`PMModern`) and helper utilities.
- `vendor` – Mbed TLS config and platform glue.
- `tools` – Asset generator, modern bundle script, and GitHub deployment scripts.

## Offline editor and graphs

Typed numeric expressions, linear/quadratic equations and simple isolated cubic/fourth powers can be solved locally. Incomplete formulas, domain errors, unsupported equations and results outside the supported number range return an explanation; the editor and its draft remain available. A trailing `=` or `=?` evaluates a numeric expression. Variable expressions without `=` keep the existing roots-of-expression convention.

The raw input has a visible native caret, cursor arrows and Next Field navigation. Empty fractions, roots and powers receive preview-only square placeholders immediately. They never enter the saved or solved expression. Drafts survive reopening the editor.

View Graph plots real-valued expressions and `y=…`/`f(x)=…` functions locally. Other equations plot left minus right so intersections with zero identify solutions. Drag to pan and pinch or use +/− to zoom; poles and undefined values are omitted. This does not add a general symbolic solver or a new server.

The ARMv7 package targets iOS 5.0–10.x. Physical checks use iPad 2 / iOS 6.1.3 and iPhone X / iOS 16.7.16; iOS 5 and 7–10 still need physical-device coverage. The rootless DEB requires iOS 15+; the ARM64 IPA requires iOS 14+.
