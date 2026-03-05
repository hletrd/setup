---
name: playwright
version: 1.0.0
description: |
  Browser automation and testing using Playwright CLI and scripts. Replaces
  the @playwright/mcp MCP server with direct npx playwright commands and
  temporary script files.
allowed-tools:
  - Bash
  - Read
  - Write
---

# Playwright: Browser Automation & Testing

You handle browser automation using Playwright's CLI tools and scripted tests.

## Quick Commands

### Open a URL in browser
```sh
npx playwright open <url>
```

### Take a screenshot
```sh
npx playwright screenshot <url> /tmp/screenshot.png
```

### Generate test code interactively
```sh
npx playwright codegen <url>
```

### Run a test file
```sh
npx playwright test <test-file>
```

## Scripted Automation

For complex interactions (clicking, filling forms, navigating), write a temporary script:

```javascript
// /tmp/pw-script.mjs
import { chromium } from 'playwright';

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
await page.goto('https://example.com');
await page.screenshot({ path: '/tmp/result.png' });
// ... interactions ...
await browser.close();
```

Run with:
```sh
node /tmp/pw-script.mjs
```

## Tool Mapping

| MCP Tool | Replacement |
|----------|-------------|
| `browser_navigate` | `page.goto(url)` in script |
| `browser_click` | `page.click(selector)` in script |
| `browser_fill_form` | `page.fill(selector, value)` in script |
| `browser_take_screenshot` | `npx playwright screenshot <url> <path>` or `page.screenshot()` |
| `browser_snapshot` | `page.content()` in script |
| `browser_evaluate` | `page.evaluate(fn)` in script |
| `browser_press_key` | `page.keyboard.press(key)` in script |
| `browser_type` | `page.keyboard.type(text)` in script |
| `browser_select_option` | `page.selectOption(selector, value)` in script |
| `browser_hover` | `page.hover(selector)` in script |
| `browser_drag` | `page.dragAndDrop(src, dst)` in script |
| `browser_wait_for` | `page.waitForSelector(sel)` in script |
| `browser_close` | `browser.close()` in script |
| `browser_console_messages` | Listen to `page.on('console', ...)` |
| `browser_network_requests` | Listen to `page.on('request', ...)` |
| `browser_file_upload` | `page.setInputFiles(selector, path)` in script |
| `browser_tabs` | `browser.contexts()[0].pages()` in script |
| `browser_navigate_back` | `page.goBack()` in script |
| `browser_resize` | `page.setViewportSize({width, height})` in script |
| `browser_handle_dialog` | `page.on('dialog', ...)` in script |
| `browser_install` | `npx playwright install` |

## Guidelines

- Prefer `npx playwright screenshot` for simple screenshot tasks
- Use scripted approach for multi-step interactions
- Write scripts to `/tmp/pw-*.mjs` and clean up after
- Use `headless: true` by default unless user needs to see the browser
- Install browsers first if needed: `npx playwright install chromium`
