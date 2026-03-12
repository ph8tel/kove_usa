import { test, expect, type Page } from '@playwright/test';

/**
 * Kove Moto USA — Authentication pages (/users/log-in, /users/register)
 *
 * These tests cover:
 *  - Login page structure and the Google OAuth button
 *  - Registration page structure and the Google OAuth button
 *  - Full Google OAuth login flow (mock server handles the Google dance)
 *  - Full Google OAuth registration flow (new user created via OAuth)
 *
 * The Google OAuth endpoints are intercepted by the local mock server
 * (e2e/support/mock-api-server.cjs) which:
 *   1. GET /google/o/oauth2/v2/auth → immediately redirects back to
 *      /auth/google/callback with `code=mock_google_auth_code` + original state
 *   2. POST /google/oauth2/token     → returns a fake access_token
 *   3. GET /google/oauth2/v3/userinfo → returns a fixed fake user profile
 *      { sub: "mock_google_sub_e2e_test_001", email: "e2e-rider@test.kove" }
 *
 * Phoenix is started with GOOGLE_OAUTH_BASE_URL=http://localhost:4444/google so
 * all three endpoints above are hit instead of the real Google APIs.
 *
 * NOTE: The mock always returns the same user (e2e-rider@test.kove).
 * On the first run the user is created; on subsequent runs the existing user is
 * returned (the "returning Google user" path). Both paths end at /home.
 */

async function waitForLiveSocket(page: Page): Promise<void> {
  await page.waitForFunction(
    () => (window as any).liveSocket?.isConnected() === true,
    { timeout: 10_000 }
  );
}

// ---------------------------------------------------------------------------
// Login page — structure
// ---------------------------------------------------------------------------

test.describe('Login page — structure', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/users/log-in');
    await waitForLiveSocket(page);
  });

  test('has the correct page title', async ({ page }) => {
    await expect(page).toHaveTitle(/Kove Moto USA/i);
  });

  test('shows the Log in heading', async ({ page }) => {
    await expect(page.getByRole('heading', { name: /log in/i })).toBeVisible();
  });

  test('shows the magic-link email form', async ({ page }) => {
    await expect(page.locator('#login_form_magic')).toBeVisible();
  });

  test('shows the password form', async ({ page }) => {
    await expect(page.locator('#login_form_password')).toBeVisible();
  });

  test('shows the "Continue with Google" button', async ({ page }) => {
    const googleBtn = page.getByRole('link', { name: /continue with google/i });
    await expect(googleBtn).toBeVisible();
    await expect(googleBtn).toHaveAttribute('href', '/auth/google');
  });

  test('has a link to the registration page', async ({ page }) => {
    await expect(page.getByRole('link', { name: /sign up/i })).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Registration page — structure
// ---------------------------------------------------------------------------

test.describe('Registration page — structure', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/users/register');
    await waitForLiveSocket(page);
  });

  test('shows the Register heading', async ({ page }) => {
    await expect(
      page.getByRole('heading', { name: /register for an account/i })
    ).toBeVisible();
  });

  test('shows the registration form', async ({ page }) => {
    await expect(page.locator('#registration_form')).toBeVisible();
  });

  test('shows the "Continue with Google" button', async ({ page }) => {
    const googleBtn = page.getByRole('link', { name: /continue with google/i });
    await expect(googleBtn).toBeVisible();
    await expect(googleBtn).toHaveAttribute('href', '/auth/google');
  });

  test('has a link back to the login page', async ({ page }) => {
    await expect(page.getByRole('link', { name: /log in/i }).first()).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Google OAuth flow — full round-trip via mock server
// ---------------------------------------------------------------------------

test.describe('Google OAuth — full login/register flow', () => {
  test('logs in (or registers) via Google and lands on /home', async ({ page }) => {
    await page.goto('/users/log-in');
    await waitForLiveSocket(page);

    // Click the "Continue with Google" button — this is a plain <a href>,
    // so it triggers a real browser navigation (not a LiveView event).
    await page.getByRole('link', { name: /continue with google/i }).click();

    // The mock server's /google/o/oauth2/v2/auth handler immediately redirects
    // back to /auth/google/callback with the mock code + original state token.
    // Phoenix then calls the mock token and userinfo endpoints, finds or creates
    // the user, and redirects to /home.
    await page.waitForURL('/home', { timeout: 15_000 });

    // Verify the rider is authenticated and on their garage page.
    await expect(page.getByText('My Garage').first()).toBeVisible();
  });

  test('shows an error flash if Google denies access', async ({ page }) => {
    // Simulate the user clicking "Cancel" on the Google consent screen.
    // Google redirects back with ?error=access_denied instead of a code.
    await page.goto('/auth/google/callback?error=access_denied');

    await page.waitForURL('/users/log-in');
    await expect(page.getByText(/google sign-in was cancelled/i)).toBeVisible();
  });

  test('clicking Google button from register page also works', async ({ page }) => {
    await page.goto('/users/register');
    await waitForLiveSocket(page);

    await page.getByRole('link', { name: /continue with google/i }).click();

    // Same flow — mock completes it and the user lands on /home.
    await page.waitForURL('/home', { timeout: 15_000 });
    await expect(page.getByText('My Garage').first()).toBeVisible();
  });
});
