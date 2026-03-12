import { defineConfig, devices } from '@playwright/test';

/**
 * Kove Moto USA — Playwright configuration
 *
 * Two servers are started automatically before tests run:
 *
 *  1. mock-api-server (port 4444) — local Node.js server that stubs the Groq
 *     and OpenAI APIs so tests never hit the real internet.
 *
 *  2. Phoenix (port 4000) — the app itself, started with GROQ_BASE_URL and
 *     OPENAI_BASE_URL pointing at the mock server.
 *
 * In development you can skip auto-start by running the servers yourself:
 *   $ node e2e/support/mock-api-server.cjs
 *   $ GROQ_BASE_URL=http://localhost:4444 OPENAI_BASE_URL=http://localhost:4444 mix phx.server
 * then `npx playwright test` will reuse the already-running processes.
 *
 * See https://playwright.dev/docs/test-configuration
 */
export default defineConfig({
  testDir: './e2e',

  /** Run spec files in parallel; individual tests within a file run serially. */
  fullyParallel: true,

  /** Hard-fail the CI run if a `test.only` was accidentally committed. */
  forbidOnly: !!process.env.CI,

  /** Retry flaky tests once on CI; no retries locally. */
  retries: process.env.CI ? 1 : 0,

  /** Single worker on CI to avoid port conflicts; cap at 2 locally so the
   *  Phoenix dev server isn't overwhelmed by parallel WebSocket connections. */
  workers: process.env.CI ? 1 : 2,

  reporter: 'html',

  use: {
    /** All `page.goto('/')` calls resolve against the Phoenix dev server. */
    baseURL: process.env.BASE_URL ?? 'http://localhost:4000',

    /** Capture a full trace on the first retry of a failed test. */
    trace: 'on-first-retry',

    /** Global timeout per action (click, fill, etc.). */
    actionTimeout: 10_000,
  },

  /** Default timeout for each test (ms). */
  timeout: 30_000,

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
  ],

  webServer: [
    {
      /**
       * Start the mock API server first.  Phoenix will connect to it once
       * GROQ_BASE_URL / OPENAI_BASE_URL are set below.
       */
      command: 'node e2e/support/mock-api-server.cjs',
      url: 'http://localhost:4444/health',
      /** Reuse locally so you can keep the mock server running; always fresh on CI. */
      reuseExistingServer: !process.env.CI,
      timeout: 15_000,
    },
    {
      /**
       * Start Phoenix with the mock base URLs injected so Groq/OpenAI calls
       * hit the local mock server instead of the real internet.
       *
       * On CI a fresh server is always started.
       * Locally, if Phoenix is already running it is reused (make sure you
       * started it with the same env vars — see comment at the top of this file).
       */
      command: 'mix phx.server',
      url: 'http://localhost:4000',
      reuseExistingServer: !process.env.CI,
      timeout: 120_000,
      env: {
        GROQ_BASE_URL: 'http://localhost:4444',
        OPENAI_BASE_URL: 'http://localhost:4444',
        // Provide a dummy key so the Groq module doesn't short-circuit with
        // "API key not configured" before it even reaches the mock server.
        GROQ_API_KEY: 'mock-api-key-for-e2e-tests',
        OPENAI_API_KEY: 'mock-api-key-for-e2e-tests',
      },
    },
  ],
});
