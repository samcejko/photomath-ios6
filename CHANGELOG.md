# Changelog

## [1.0.0] - 2026-10-16

### Initial Release
- **Camera Math Scanner**: Real-time camera viewfinder with animated laser reticle and tap-to-focus on iOS 6 (`AVCaptureSession`).
- **Interactive Viewfinder**: Resizable/draggable crop window to accurately isolate printed or handwritten equations.
- **Manual Math Keyboard**: Full on-screen math input with fractions, exponents, square roots, parentheses, algebraic variables, and trigonometry.
- **Dynamic Model Fallback**: OpenRouter integration fetching live vision models at runtime without hardcoded model lists, filtering out content-safety/moderation filters, and automatically falling back to subsequent models on failure.
- **Step-by-Step Solutions**: Clear, detailed pedagogical explanations breaking down every equation transformation.
- **Native LaTeX Rendering**: Embedded `iosMath` engine rendering beautiful mathematical formulas on 32-bit iOS 6 devices.
- **History & Offline Cache**: Saved equations and solution steps for instant offline review.
- **Skeuomorphic iOS 6 Design**: Classic glossy toolbars, textured navigation bars, and buttons.
- **Bilingual Interface**: Full English (`en`) and Czech (`cs`) localization.
- **Dual Package Support**: 32-bit armv7 for iOS 6.x (Cydia deb + ipainstaller) and 64-bit arm64 for iOS 14–17 (rootless jailbreaks and TrollStore).
