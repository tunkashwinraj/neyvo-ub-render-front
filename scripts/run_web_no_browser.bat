@echo off
REM Run Flutter web without opening Chrome. Open http://localhost:9090 in your browser when ready.
REM Hot reload: press 'r' in this terminal when you save a file (or use flutter_w for auto reload).
flutter run -d web-server --web-port=9090 --dart-define=NEYVO_PULSE=true --dart-define=BACKEND_BASE=http://127.0.0.1:8000 %*
