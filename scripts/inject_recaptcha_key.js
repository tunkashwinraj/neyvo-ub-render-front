#!/usr/bin/env node
/**
 * Injects the reCAPTCHA v3 site key into build/web/index.html so it matches
 * the key used at build time (--dart-define=RECAPTCHA_V3_SITE_KEY=...).
 * Run after: flutter build web --dart-define=RECAPTCHA_V3_SITE_KEY=YOUR_KEY
 *
 * Usage:
 *   RECAPTCHA_V3_SITE_KEY=your_key node scripts/inject_recaptcha_key.js
 *   node scripts/inject_recaptcha_key.js your_key
 */
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..');
const INDEX_PATH = path.join(ROOT, 'build', 'web', 'index.html');

const key = process.env.RECAPTCHA_V3_SITE_KEY || process.argv[2] || '';

if (!key.trim()) {
  console.warn('inject_recaptcha_key.js: No RECAPTCHA_V3_SITE_KEY (env or arg). Leaving index.html unchanged.');
  process.exit(0);
}

if (!fs.existsSync(INDEX_PATH)) {
  console.error('inject_recaptcha_key.js: build/web/index.html not found. Run "flutter build web" first.');
  process.exit(1);
}

let html = fs.readFileSync(INDEX_PATH, 'utf8');
// Replace the render=... value in the reCAPTCHA v3 script src
const re = /(src="https:\/\/www\.google\.com\/recaptcha\/api\.js\?render=)([^"]+)("/);
if (!re.test(html)) {
  console.error('inject_recaptcha_key.js: Could not find reCAPTCHA v3 script tag in index.html');
  process.exit(1);
}
html = html.replace(re, `$1${key.trim()}$3`);
fs.writeFileSync(INDEX_PATH, html, 'utf8');
console.log('Injected RECAPTCHA_V3_SITE_KEY into build/web/index.html');
process.exit(0);
