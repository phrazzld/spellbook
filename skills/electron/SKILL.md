---
name: electron
description: |
  Electron desktop app architecture: IPC, process separation, preload bridge,
  BrowserWindow lifecycle, tray apps, state management, crash recovery, packaging,
  security. Reference skill for all Electron work.
  Use when: adding IPC channels, creating windows, modifying preload, tray behavior,
  main-process features, renderer/main boundary issues, packaging, security review,
  "electron", "ipc", "preload", "tray", "BrowserWindow", "main process", "renderer".
argument-hint: <area> e.g. "add ipc channel" or "new window" or "tray menu"
---

# Electron Desktop App Patterns

Reference for Electron apps with typed IPC, process isolation, and
main-process-as-source-of-truth architecture.

## Process Model

```
┌─────────────────────────────────────┐
│  Main Process (Node.js)             │
│  - App state, file I/O, auth        │
│  - ALL network calls (APIs, OAuth)  │
│  - Tray, menus, native dialogs      │
│  - IPC handlers (ipcMain.handle)    │
│  - Optional tick loop → broadcast   │
├─────────────────────────────────────┤
│  Preload (contextBridge)            │
│  - Typed API object on window       │
│  - invoke() for request/response    │
│  - on() + callback for push events  │
├─────────────────────────────────────┤
│  Renderer (Chromium, React/etc)     │
│  - Pure UI, no Node, no fs, no net  │
│  - Receives state from main         │
│  - Calls API methods for mutations  │
└─────────────────────────────────────┘
```

**Iron rule:** Renderer never touches Node APIs, filesystem, or network directly.
Everything flows through the preload bridge.

## IPC Patterns

### The Three Layers

**1. Shared types** -- Single interface defines every channel the renderer can call.
Both preload and IPC handlers import it.

```typescript
// shared/types.ts — the contract
export interface AppAPI {
  getState(): Promise<AppSnapshot>;
  doAction(param: string): Promise<void>;
  onStateChange(callback: (snapshot: AppSnapshot) => void): () => void;
  // ... every renderer↔main interaction
}
```

**2. IPC handlers** -- `ipcMain.handle` for each channel. Validate all args at the
boundary. Return values or throw — errors propagate to renderer.

```typescript
function handleIpc(channel: string, handler: IpcHandler): void {
  ipcMain.handle(channel, async (event, ...args) => {
    try { return await handler(event, ...args); }
    catch (error) { throw toIpcError(error); }
  });
}

handleIpc('app:do-action', (_event, param) => {
  appState.doAction(requireNonEmptyString(param, 'param'));
  onMutation();
});
```

**3. Preload bridge** -- Maps the typed API to `ipcRenderer.invoke`.

```typescript
const appAPI: AppAPI = {
  getState: () => ipcRenderer.invoke('app:get-state'),
  doAction: (param) => ipcRenderer.invoke('app:do-action', param),
  onStateChange: (callback) => {
    const handler = (_e, snapshot) => callback(snapshot);
    ipcRenderer.on('app:state-change', handler);
    return () => ipcRenderer.removeListener('app:state-change', handler);
  },
};
contextBridge.exposeInMainWorld('appAPI', appAPI);
```

### invoke/handle vs send/on

| Pattern | Direction | Use |
|---------|-----------|-----|
| `invoke` / `handle` | Renderer -> Main (request/response) | Commands, queries — anything that returns a value or can fail |
| `send` / `on` | Main -> Renderer (push) | Broadcasts: state snapshots, navigation events, focus state |

**Prefer invoke/handle for everything renderer-initiated.** It returns a Promise,
propagates errors, and maps cleanly to async function calls.

Use `send`/`on` only for main-to-renderer push (broadcast pattern).

### Channel Naming Convention

Namespace with colon: `domain:action`. Examples:
- `app:get-state`, `app:do-action`
- `config:get`, `config:save`
- `auth:sign-in`, `auth:sign-out`
- `window:navigate`, `window:focus`

### Validation at the Boundary

**Every IPC handler validates every argument.** The renderer is untrusted.

```typescript
function requireNonEmptyString(value: unknown, field: string): string {
  if (typeof value !== 'string' || value.trim().length === 0)
    throw new Error(`${field} must be a non-empty string`);
  return value;
}
```

Build a small library of validators: `requireNonEmptyString`, `requireBoolean`,
`requireNumber`, `requireIsoTimestamp`, etc. Compose them for complex
objects (`requireUserInput`, `requireConfigData`).

### Push Events with Cleanup

Preload `on*` methods return unsubscribe functions. Renderer hooks call the
unsub in cleanup:

```typescript
// preload
onStateChange: (callback) => {
  const handler = (_e, snapshot) => callback(snapshot);
  ipcRenderer.on('app:state-change', handler);
  return () => ipcRenderer.removeListener('app:state-change', handler);
},

// renderer hook
useEffect(() => {
  const unsub = window.appAPI.onStateChange(setState);
  return unsub;
}, []);
```

### Buffering for Late Listeners

When main sends a push event before the renderer has registered a listener
(e.g., window just opened), buffer the last value:

```typescript
let pending: string | null | undefined;
const listeners = new Set<(v: string | null) => void>();

ipcRenderer.on('window:show-target', (_e, targetId) => {
  if (listeners.size === 0) { pending = targetId; return; }
  for (const fn of listeners) fn(targetId);
});

// When listener registers, flush pending
onShowTarget: (callback) => {
  listeners.add(callback);
  if (pending !== undefined) {
    const v = pending; pending = undefined; callback(v);
  }
  return () => listeners.delete(callback);
},
```

## Adding a New IPC Channel

Checklist (touch exactly 3 files):

1. **Shared types** -- Add method to API interface. Add any new types.
2. **IPC handlers** -- Add `handleIpc('domain:action', ...)` with argument validation.
3. **Preload** -- Add corresponding `ipcRenderer.invoke(...)` call on the API object.

If it's a push event (main -> renderer), also add the `ipcRenderer.on` listener
in preload and the unsubscribe-returning method on the API interface.

## BrowserWindow Lifecycle

### Show/Hide vs Create/Destroy

**Prefer show/hide for persistent windows.** Creating a BrowserWindow is expensive
(spawns a renderer process, loads HTML/JS). Hide on close, show on activate:

```typescript
mainWindow.on('close', (e) => {
  if (!isQuitting) { e.preventDefault(); mainWindow.hide(); }
});
```

Set an `isQuitting` flag in `before-quit` so the window actually closes on app exit.

**Create/destroy only for transient windows** (dialogs, OAuth popups, onboarding).

### Window Options

```typescript
new BrowserWindow({
  show: false,                    // Always — show after ready-to-show
  webPreferences: {
    preload: path.join(__dirname, 'preload.js'),
    contextIsolation: true,       // MANDATORY
    nodeIntegration: false,       // MANDATORY
  },
});

win.once('ready-to-show', () => win.show());  // No flash of empty window
```

### Multiple Windows, One Preload

All windows share the same preload script and the same API. Broadcast events
hit every open window via `BrowserWindow.getAllWindows()`.

### Routing Multiple Views

Use URL hash to route different views through a single HTML entry point:

```typescript
// Main window
loadWindowContent(win, { devServerUrl, prodPath, hash: 'main' });
// Secondary window
loadWindowContent(secondary, { devServerUrl, prodPath, hash: 'settings' });
```

The renderer reads `window.location.hash` to decide which root component to mount.

## Tray App Patterns

### No Dock Icon (macOS)

```typescript
if (process.platform === 'darwin' && app.dock) app.dock.hide();
```

Conditionally show dock (`app.dock.show()`) when you want the app in
Cmd+Tab (e.g., when a main window is visible).

### Panel Positioning

Position a frameless panel below the tray icon (macOS) or above it (Windows):

```typescript
const trayBounds = tray.getBounds();
const panelBounds = panel.getBounds();

let x = Math.round(trayBounds.x + trayBounds.width / 2 - panelBounds.width / 2);
let y = process.platform === 'darwin'
  ? trayBounds.y + trayBounds.height    // Below menu bar
  : trayBounds.y - panelBounds.height;  // Above taskbar

// Clamp to display work area
const { x: wx, y: wy, width: ww, height: wh } = display.workArea;
x = Math.max(wx, Math.min(x, wx + ww - panelBounds.width));
y = Math.max(wy, Math.min(y, wy + wh - panelBounds.height));
```

### Panel Blur Behavior (macOS)

On macOS, use `type: 'panel'` with vibrancy. Handle the blur/focus dance:

```typescript
panel = new BrowserWindow({
  frame: false, alwaysOnTop: true, skipTaskbar: true,
  type: 'panel',
  vibrancy: 'under-window',
  visualEffectState: 'active',
});

let allowBlurHide = false;
panel.on('focus', () => { allowBlurHide = true; });
panel.on('blur', () => { if (allowBlurHide) { allowBlurHide = false; panel.hide(); } });
```

The `allowBlurHide` guard prevents the panel from hiding immediately on show
(Windows fires blur before the window receives focus from the tray click).

### Tray Title Updates

Update tray title (macOS menu bar text) in the tick/broadcast loop:

```typescript
tray.setTitle(formatStatus(currentState));
```

Keep tray update logic sync -- it may run every second.

## State Management

### Main Process = Source of Truth

All state lives in the main process. The renderer is a view.

```
State (main) → buildSnapshot() → broadcastToAllWindows() → renderer setState
                   ↑ sync — no async calls allowed in broadcast path
```

### Broadcast Pattern

Build a snapshot and push it to all windows on every state change (or on a timer):

```typescript
function broadcastToAllWindows(state: AppState): void {
  const snapshot = buildSnapshot(state);  // SYNC — no await
  for (const win of BrowserWindow.getAllWindows()) {
    if (!win.isDestroyed()) win.webContents.send('app:state-change', snapshot);
  }
}
```

**Critical:** `buildSnapshot()` must be synchronous. Any data it needs from
external sources (auth state, remote config) must be pre-cached in module-level
variables with sync accessors.

### Mutation Pattern

Mutations follow a consistent flow:

```
IPC handler validates args → calls state method → calls onMutation()
onMutation() = persistState + updateTray + updateMenus + notify watchers
```

### Atomic File Persistence

State persists to disk via atomic write (write to `.tmp`, rename over target):

```typescript
import { writeFileSync, renameSync } from 'fs';

function persistState(filePath: string, data: unknown): void {
  const tmp = filePath + '.tmp';
  writeFileSync(tmp, JSON.stringify(data, null, 2));
  renameSync(tmp, filePath);
}
```

Optional heartbeat (e.g., every 60s) to update a `last_active` timestamp for
crash recovery.

## Crash Recovery

On startup, check if previous state indicates an unclean shutdown:

1. Load state file -- if it contains an "in progress" marker, the app died mid-operation.
2. Check `last_active` timestamp -- how long ago was the heartbeat?
3. Show dialog offering recovery options (e.g., "Resume", "End at last-known time", "Discard").

The heartbeat (periodic `last_active` + persist) is what makes this work.
Without it, you can't know when the state was last valid.

## OAuth in BrowserWindow

For OAuth flows (Microsoft, Google, GitHub, etc.), intercept the callback URL
in a dedicated BrowserWindow:

```typescript
const authWin = new BrowserWindow({ width: 500, height: 700 });
authWin.loadURL(authorizationUrl);

authWin.webContents.on('will-redirect', (event, url) => {
  if (url.startsWith(callbackUrl)) {
    event.preventDefault();
    const code = new URL(url).searchParams.get('code');
    exchangeCodeForToken(code);
    authWin.close();
  }
});
```

Always close the auth window after extracting the token. Handle the user closing
the window manually (cancel flow).

## Security Checklist

- `contextIsolation: true` -- always. Renderer can't access Node globals.
- `nodeIntegration: false` -- always. Renderer can't `require('fs')`.
- Preload exposes only the typed API object via `contextBridge.exposeInMainWorld`.
  Never expose `ipcRenderer` directly.
- Validate all IPC arguments in handlers. Renderer is untrusted.
- No `eval()`, no `new Function()` in renderer.
- Network calls (OAuth, APIs) happen in main process only.
- `webSecurity: true` (default) -- never disable. Prevents CORS bypass.
- CSP headers -- set restrictive Content-Security-Policy in HTML or via
  `session.defaultSession.webRequest.onHeadersReceived`.

## Packaging

### Electron Forge + Vite

- **Dev:** `npm start` runs Electron Forge with Vite (esbuild transpilation).
- **Build:** `npm run package` or `npm run make` produces platform binaries.
- **Forge globals:** `MAIN_WINDOW_VITE_DEV_SERVER_URL` and `MAIN_WINDOW_VITE_NAME`
  for switching between dev server and packaged HTML:
  ```typescript
  if (MAIN_WINDOW_VITE_DEV_SERVER_URL) win.loadURL(url);
  else win.loadFile(rendererPath());
  ```
- **Kill dev process:** `pkill -f "electron-forge"`. Never `pkill -f "Electron"`
  -- that kills VS Code and every other Electron app on the machine.

### electron-builder

- Configure in `electron-builder.yml` or `package.json` `"build"` key.
- `npm run build` then `npm run dist` for platform binaries.

### Assets

- **Dev:** Resolve from `app.getAppPath()/assets`.
- **Production:** From `process.resourcesPath/assets` (files listed in
  `extraResources` in your builder config).

### Platform-Specific

- **Windows (Squirrel):** Handle `electron-squirrel-startup` early -- quit
  immediately during install/update events.
- **macOS:** Sign with `codesign`, notarize with `notarytool`. Without
  notarization, Gatekeeper blocks the app.
- **Linux:** AppImage for broad compat, `.deb`/`.rpm` for package managers.

## Anti-Patterns

- **Exposing `ipcRenderer` directly to renderer.** Use `contextBridge` with a typed API.
- **Async calls in the broadcast path.** Snapshots must be sync. Pre-cache everything.
- **Creating windows on every action.** Show/hide persistent windows instead.
- **Unvalidated IPC arguments.** Every handler validates. The renderer is untrusted.
- **`nodeIntegration: true`.** Never. Not even "just for dev".
- **Storing state in the renderer.** Main process is source of truth. Renderer is ephemeral.
- **`pkill -f "Electron"` to kill dev.** Kills VS Code. Use `pkill -f "electron-forge"` or your specific process name.
- **Blocking the main process.** Long-running sync operations (large file reads, crypto) block all windows. Use worker threads or chunk the work.
- **`webSecurity: false`.** Disables same-origin policy. Never do this, even for development.
- **Unhandled window lifecycle.** Always handle `close`, `closed`, `ready-to-show`. Forgetting `ready-to-show` causes white flash. Forgetting `close` prevention causes data loss.
