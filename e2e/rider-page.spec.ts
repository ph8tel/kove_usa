import { test, expect, type Page } from '@playwright/test';

/**
 * Kove Moto USA — Rider Page (/@handle)
 *
 * These tests cover the public rider profile page which is the sharable URL
 * that riders post in Facebook groups.
 *
 * Test strategy:
 *  - Unknown handle → redirected to storefront with an error flash
 *  - Known handle   → public page renders correctly (heading, share button,
 *                     OG meta tags, footer CTA, empty-garage state)
 *  - Nav link       → "My Page" link is visible in the header for logged-in users
 *  - Settings       → handle form section is present in account settings
 *
 * The "known handle" tests require a real DB user. We reuse the same Google
 * OAuth mock user (e2e-rider@test.kove) that auth.spec.ts creates, log in to
 * grab the auto-generated handle from the "My Page" nav link, then visit the
 * rider page directly.
 *
 * No Groq/OpenAI calls are made by the rider page, so the mock server is only
 * needed to keep the Phoenix server startup happy.
 */

async function waitForLiveSocket(page: Page): Promise<void> {
  await page.waitForFunction(
    () => (window as any).liveSocket?.isConnected() === true,
    { timeout: 10_000 }
  );
}

/**
 * Log in via the Google OAuth mock flow and return to /home.
 * Returns the rider handle scraped from the "My Page" nav link.
 */
async function loginAndGetHandle(page: Page): Promise<string> {
  await page.goto('/users/log-in');
  await waitForLiveSocket(page);
  await page.getByRole('link', { name: /continue with google/i }).click();
  await page.waitForURL('/home', { timeout: 15_000 });

  // The "My Page" nav link href is /@<handle>
  const myPageLink = page.locator('a[href^="/@"]').first();
  await expect(myPageLink).toBeVisible({ timeout: 5_000 });
  const href = await myPageLink.getAttribute('href');
  // href is "/@motomike_1234", strip leading "/@"
  return href!.slice(2);
}

// ---------------------------------------------------------------------------
// Unknown handle — 404 redirect
// ---------------------------------------------------------------------------

test.describe('Rider page — unknown handle', () => {
  test('redirects to the storefront and shows an error flash', async ({ page }) => {
    await page.goto('/@this-handle-does-not-exist-xyz');
    await waitForLiveSocket(page);

    // LiveView redirects to /
    await expect(page).toHaveURL(/\/$/, { timeout: 10_000 });

    // Error flash is shown
    await expect(page.getByText(/rider page not found/i)).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Known handle — public page structure
// ---------------------------------------------------------------------------

test.describe('Rider page — page structure', () => {
  let handle: string;

  test.beforeAll(async ({ browser }) => {
    const page = await browser.newPage();
    handle = await loginAndGetHandle(page);
    await page.close();
  });

  test.beforeEach(async ({ page }) => {
    await page.goto(`/@${handle}`);
    await waitForLiveSocket(page);
  });

  test('has the correct page title', async ({ page }) => {
    await expect(page).toHaveTitle(new RegExp(handle, 'i'));
  });

  test('displays @handle as the main heading', async ({ page }) => {
    const heading = page.getByRole('heading', { level: 1 });
    await expect(heading).toBeVisible();
    await expect(heading).toContainText(`@${handle}`);
  });

  test('shows the empty-garage state when no bike is registered', async ({ page }) => {
    // The E2E user has not registered a bike, so the empty state is shown
    await expect(
      page.getByText("This rider hasn't set up their garage yet.")
    ).toBeVisible();
  });

  test('shows the Share button', async ({ page }) => {
    await expect(page.locator('#share-btn')).toBeVisible();
  });

  test('shows the footer CTA with Explore link', async ({ page }) => {
    await expect(
      page.getByRole('link', { name: /explore kove moto usa/i })
    ).toBeVisible();
  });

  test('is publicly accessible without login', async ({ browser }) => {
    // Open a brand-new context with no session cookies
    const ctx = await browser.newContext();
    const freshPage = await ctx.newPage();
    await freshPage.goto(`/@${handle}`);
    await waitForLiveSocket(freshPage);

    await expect(
      freshPage.getByRole('heading', { level: 1 })
    ).toContainText(`@${handle}`);

    await ctx.close();
  });
});

// ---------------------------------------------------------------------------
// Open Graph meta tags
// ---------------------------------------------------------------------------

test.describe('Rider page — Open Graph meta tags', () => {
  let handle: string;

  test.beforeAll(async ({ browser }) => {
    const page = await browser.newPage();
    handle = await loginAndGetHandle(page);
    await page.close();
  });

  test('og:title is set', async ({ page }) => {
    await page.goto(`/@${handle}`);
    const ogTitle = page.locator('meta[property="og:title"]');
    await expect(ogTitle).toHaveAttribute('content', new RegExp(handle, 'i'));
  });

  test('og:description is set', async ({ page }) => {
    await page.goto(`/@${handle}`);
    const ogDesc = page.locator('meta[property="og:description"]');
    await expect(ogDesc).toHaveAttribute('content', /.+/);
  });

  test('og:url points to the rider page', async ({ page }) => {
    await page.goto(`/@${handle}`);
    const ogUrl = page.locator('meta[property="og:url"]');
    await expect(ogUrl).toHaveAttribute('content', new RegExp(`/@${handle}`));
  });

  test('og:type is "profile"', async ({ page }) => {
    await page.goto(`/@${handle}`);
    const ogType = page.locator('meta[property="og:type"]');
    await expect(ogType).toHaveAttribute('content', 'profile');
  });

  test('twitter:card is set', async ({ page }) => {
    await page.goto(`/@${handle}`);
    const twitterCard = page.locator('meta[name="twitter:card"]');
    await expect(twitterCard).toHaveAttribute('content', 'summary_large_image');
  });

  test('storefront does NOT emit OG tags', async ({ page }) => {
    await page.goto('/');
    await expect(page.locator('meta[property="og:title"]')).toHaveCount(0);
  });
});

// ---------------------------------------------------------------------------
// Navigation — "My Page" header link
// ---------------------------------------------------------------------------

test.describe('Rider page — nav link', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/users/log-in');
    await waitForLiveSocket(page);
    await page.getByRole('link', { name: /continue with google/i }).click();
    await page.waitForURL('/home', { timeout: 15_000 });
  });

  test('shows the "My Page" link in the header when logged in', async ({ page }) => {
    const myPageLink = page.getByRole('link', { name: /my page/i });
    await expect(myPageLink).toBeVisible();
  });

  test('"My Page" link href starts with /@', async ({ page }) => {
    const myPageLink = page.locator('a[href^="/@"]').first();
    await expect(myPageLink).toBeVisible();
    await expect(myPageLink).toHaveAttribute('href', /^\/@[a-z0-9_]+$/);
  });

  test('clicking "My Page" navigates to the rider page', async ({ page }) => {
    // The "Signed in with Google!" flash overlaps the nav bar after login —
    // wait for it to disappear before attempting the click.
    await page.locator('#flash-group').getByText(/signed in with google/i).waitFor({ state: 'hidden', timeout: 10_000 }).catch(() => {});

    const myPageLink = page.locator('a[href^="/@"]').first();
    await myPageLink.click();
    await expect(page).toHaveURL(/\/@[a-z0-9_]+$/, { timeout: 10_000 });
  });
});

// ---------------------------------------------------------------------------
// Settings — handle form
// ---------------------------------------------------------------------------

test.describe('Rider page — settings handle form', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/users/log-in');
    await waitForLiveSocket(page);
    await page.getByRole('link', { name: /continue with google/i }).click();
    await page.waitForURL('/home', { timeout: 15_000 });
    await page.goto('/users/settings');
    await waitForLiveSocket(page);
  });

  test('shows the handle form', async ({ page }) => {
    await expect(page.locator('#handle_form')).toBeVisible();
  });

  test('shows the "Rider Handle" label', async ({ page }) => {
    await expect(page.getByText('Rider Handle')).toBeVisible();
  });

  test('shows the live preview URL containing the current handle', async ({ page }) => {
    await expect(page.getByText(/kove\.fly\.dev\/@/)).toBeVisible();
  });
});
