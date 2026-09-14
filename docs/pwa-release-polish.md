# PWA release polish

Scope: Hosting response headers and PWA metadata only. No deployment performed.

## Metadata and headers

Manifest and HTML use ILND and “Small daily steps for your wellbeing.”
Manifest keeps cream #F6F5F1, green #13763E, standalone, portrait-primary,
and the existing start URL/icons. HTML also declares theme-color.

Hosting adds nosniff, strict-origin-when-cross-origin, SAMEORIGIN and
Permissions-Policy: geolocation=(), usb=(). No geolocation/WebUSB usage was
found in the current client. Camera, microphone, payment, fullscreen and
clipboard policies are not restricted. SAMEORIGIN controls embedding this
application, not its outgoing OAuth redirects or embedded external resources.
Cross-origin embedding of ILND is deliberately disallowed; verify any external
preview/embed integration before using it.

## CSP: manual hardening backlog (no policy applied)

This is a source/build inventory, not a complete browser network allowlist.
Do not copy it directly into an enforcing policy.

| Directive | Requirements to verify |
| --- | --- |
| script-src | Same-origin bootstrap/main; inline splash script; dynamically imported CanvasKit JS at www.gstatic.com/flutter-canvaskit; Firebase SDK and Google sign-in script origins; WebAssembly compilation permissions. |
| style-src | Inline splash styles and styles inserted by Flutter; use hashes/nonces where feasible after observing runtime styles. |
| connect-src | Same-origin assets/WASM, gstatic CanvasKit/fonts; configured Supabase HTTPS (and WSS if realtime used), Cloud Functions origin; Firestore, Firebase Auth/token, Storage and Analytics endpoints used by enabled SDKs. |
| img-src | Same-origin bundled covers/icons; configured Firebase/Supabase storage and content-provided remote image origins; blob/data for picked images and generated previews as observed. |
| worker-src | Same-origin legacy service-worker cleanup; blob workers if a renderer/runtime requires them. |
| frame-src | Configured Firebase auth domain and Google account/sign-in frames; reCAPTCHA frames if enabled by the separate backend/App Check work. |

Generated JS contains accounts.google.com, www.googleapis.com,
content-people.googleapis.com, www.gstatic.com, fonts.gstatic.com and configured
Supabase/Functions origins. Other Firebase endpoints can be SDK-generated.
Capture authenticated, signed-out, photo upload, article/media, and PWA flows
in a staging browser before introducing a report-only policy. No unsafe wildcard
CSP, COOP or COEP was added: strict cross-origin isolation can affect popup auth
and remote assets.

## Cache and update behavior

Existing no-cache, must-revalidate policies for index.html, main.dart.js,
bootstrap, manifest, service-worker script and /assets/** are preserved.
Flutter filenames are generally stable rather than content-hashed; do not add
immutable caching merely because an internal resource manifest contains hashes.
Root/deep-route rewritten HTML response headers must be checked on Hosting;
matching a source URL and rewriting it are distinct deployment concerns.

The current generated flutter_service_worker.js is a cleanup worker: skipWaiting,
unregister, then navigate existing window clients. It has no fetch handler or
new offline cache population. Bootstrap checks an existing registration before
updating it; no custom service worker was introduced. Previously installed
PWAs still need an online update opportunity. An already-open page can keep
running the previous application until reload. Validate an existing installed
PWA across two staging releases and verify MIME/cache/security response headers
on Hosting; local compilation cannot prove deployed response behavior.

References:
- https://docs.flutter.dev/platform-integration/web/faq
- https://docs.flutter.dev/platform-integration/web/initialization
- https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers/X-Frame-Options
