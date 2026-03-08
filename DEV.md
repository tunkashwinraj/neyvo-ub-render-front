# Flutter Web Dev – Fast Start & Auto Reload

## Run without opening Chrome (faster start)

The app starts quicker when the browser is not launched automatically. Open the URL yourself when ready.

### Option A: From Cursor / VS Code (recommended)

1. Open **Run and Debug** (Ctrl+Shift+D).
2. For **run without debugging** (faster, no debugger): choose **"Flutter (web, no browser) – Run Without Debugging"** and press **Ctrl+F5** (or the "Run Without Debugging" button).
3. Or with debugger: choose **"Flutter (web, no browser)"** and press **F5**.
4. When the terminal shows "Serving at http://localhost:9090", open that URL in Chrome (or any browser).

Hot reload: with the Flutter extension, saving a `.dart` file in the editor usually triggers hot reload. Otherwise press **`r`** in the terminal.

### Option B: From terminal

```bash
# From project root (UB_Neyvo_Front)
flutter run -d web-server --web-port=9090 --dart-define=NEYVO_PULSE=true --dart-define=BACKEND_BASE=http://127.0.0.1:8000
```

Or on Windows:

```bash
scripts\run_web_no_browser.bat
```

Then open **http://localhost:9090**. Press **`r`** in the terminal to hot reload after saving files.

---

## Auto hot reload on save (like Angular)

To have changes apply as soon as you save (without pressing `r`), use **flutter_w**:

1. Install once:
   ```bash
   dart pub global activate flutter_w
   ```
2. Run with auto reload:
   ```bash
   flutter-w run -d web-server --web-port=9090 --dart-define=NEYVO_PULSE=true --dart-define=BACKEND_BASE=http://127.0.0.1:8000
   ```

`flutter_w` watches `lib/` (and optionally `pubspec.yaml` for hot restart) and triggers hot reload when you save. Ensure `dart pub global bin` is on your PATH.

---

## Summary

| Goal              | How |
|-------------------|-----|
| No browser on run | Use **"Flutter (web, no browser)"** in VS Code/Cursor, or `flutter run -d web-server --web-port=9090 ...` |
| Faster start      | Same: `web-server` avoids launching Chrome. |
| Changes reflect immediately | Use **flutter_w** (see above), or rely on the Flutter extension’s save-to-reload in the IDE. |
