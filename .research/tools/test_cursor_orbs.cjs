#!/usr/bin/env node
// Regression test for site-wide orb toggle and touch-device default.
// Execute the same preference code included in the real generated site.
'use strict';
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const root = path.resolve(__dirname, '..');
const js = fs.readFileSync(path.join(root, '_srcassets', 'app.js'), 'utf8');
const css = fs.readFileSync(path.join(root, '_srcassets', 'style.css'), 'utf8');
const builtJS = fs.readFileSync(path.join(root, 'site', 'assets', 'app.js'), 'utf8');
const builtCSS = fs.readFileSync(path.join(root, 'site', 'assets', 'style.css'), 'utf8');
assert.equal(builtJS, js, 'site app.js diverges from checked-in source');
assert.equal(builtCSS, css, 'site style.css diverges from checked-in source');
new vm.Script(js, {filename: 'app.js'});
const start = js.indexOf('/* Site-wide cursor orb preference.');
const end = js.indexOf('/* ---- PS2 OSDSYS Cursor Orbs Canvas ---- */', start);
assert.ok(start >= 0 && end > start, 'orb preferences and renderer must both exist');
assert.ok(css.includes('.cursor-orbs-disabled .ps2-orbs-canvas'), 'disabled orb CSS required');
assert.ok(css.includes('.topbar .cursor-orbs-toggle'), 'header toggle CSS required');
assert.ok(css.includes('@media (max-width: 600px)'), 'mobile header layout required');
assert.ok(js.includes('window.ps2CursorOrbs.onChange(setOrbAnimation)'), 'animation must respond to toggle');
const preference = js.slice(start, end);

function scene(coarse, initial) {
  const state = new Map();
  if (initial !== undefined) state.set('ps2-cursor-orbs:POPSLoader', initial);
  const classes = new Set(), buttons = [], mediaCallbacks = [];
  const media = {
    matches: coarse,
    addEventListener: function (name, callback) {
      if (name === 'change') mediaCallbacks.push(callback);
    }
  };
  const header = {
    querySelector: function (selector) {
      assert.equal(selector, '.search');
      return {};
    },
    insertBefore: function (el) { buttons.push(el); }
  };
  const document = {
    documentElement: {
      classList: {
        toggle: function (name, enabled) {
          if (enabled) classes.add(name); else classes.delete(name);
        }
      }
    },
    querySelector: function (selector) { return selector === '.topbar' ? header : null; },
    createElement: function (tag) {
      assert.equal(tag, 'button');
      const attrs = {}, handlers = {};
      return {
        attrs: attrs,
        handlers: handlers,
        setAttribute: function (key, val) { attrs[key] = val; },
        addEventListener: function (type, callback) { handlers[type] = callback; },
        click: function () { handlers.click(); }
      };
    }
  };
  const context = {
    document: document,
    location: {pathname: '/POPSLoader/index.html'},
    window: {matchMedia: function () { return media; }},
    localStorage: {
      getItem: function (k) { return state.get(k) ?? null; },
      setItem: function (k, value) { state.set(k, value); }
    }
  };
  vm.runInNewContext(preference, context);
  assert.equal(buttons.length, 1, 'a single header toggle must be visible');
  return {context, state, classes, button: buttons[0], media, mediaCallbacks};
}
const mobile = scene(true);
assert.equal(mobile.context.window.ps2CursorOrbs.isEnabled(), false, 'touch devices default off');
assert.equal(mobile.button.attrs['aria-pressed'], 'false');
assert.equal(mobile.button.textContent, 'Orbs Off');
assert.ok(mobile.classes.has('cursor-orbs-disabled'));
mobile.button.click();
assert.equal(mobile.context.window.ps2CursorOrbs.isEnabled(), true);
assert.equal(mobile.button.attrs['aria-pressed'], 'true');
assert.equal(mobile.state.get('ps2-cursor-orbs:POPSLoader'), 'on', 'choice persists');
const desktop = scene(false);
assert.equal(desktop.context.window.ps2CursorOrbs.isEnabled(), true, 'desktop defaults on');
desktop.button.click();
assert.equal(desktop.context.window.ps2CursorOrbs.isEnabled(), false);
assert.equal(desktop.state.get('ps2-cursor-orbs:POPSLoader'), 'off');
const restored = scene(true, 'on');
assert.equal(restored.context.window.ps2CursorOrbs.isEnabled(), true, 'saved mobile override wins');
restored.media.matches = false;
restored.mediaCallbacks.forEach(fn => fn());
assert.equal(restored.context.window.ps2CursorOrbs.isEnabled(), true, 'media changes cannot override choice');
const automatic = scene(false);
automatic.media.matches = true;
automatic.mediaCallbacks.forEach(fn => fn());
assert.equal(automatic.context.window.ps2CursorOrbs.isEnabled(), false, 'touch transition defaults off');
console.log('PASS: desktop default, mobile default-off, visible toggle, persisted override and source/build parity');
