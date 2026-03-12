import { test, expect, type Page } from '@playwright/test';

/**
 * Kove Moto USA — Bike Detail Page (/bikes/:slug)
 *
 * Covers:
 *  - Page structure: title, bike name, MSRP, category/year badge
 *  - Image slider: displays an image, prev/next/dot navigation
 *  - Spec tabs: Description, Engine, Chassis — content and switching
 *  - Navigation: "View Details" link from storefront lands here; back-nav works
 *  - Kovy chat panel (desktop): header, quick-asks, send message, streaming, re-enable
 *  - Kovy chat FAB (mobile): FAB, drawer open/close, send message, streaming
 *
 * The 800X Rally is used as the primary test bike because it has the richest
 * spec data (engine, chassis, dimensions) and a known MSRP of $12,999.
 * Slug: 2026-kove-800x-rally
 */

const RALLY_SLUG = '2026-kove-800x-rally';
const RALLY_URL = `/bikes/${RALLY_SLUG}`;

async function waitForLiveSocket(page: Page): Promise<void> {
  await page.waitForFunction(
    () => (window as any).liveSocket?.isConnected() === true,
    { timeout: 10_000 }
  );
}

// ---------------------------------------------------------------------------
// Page structure
// ---------------------------------------------------------------------------

test.describe('Bike detail — page structure', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(RALLY_URL);
    await waitForLiveSocket(page);
  });

  test('has the correct page title', async ({ page }) => {
    await expect(page).toHaveTitle(/800X Rally/i);
  });

  test('displays the bike name as the main heading', async ({ page }) => {
    await expect(page.getByRole('heading', { level: 1 })).toContainText('800X Rally');
  });

  test('displays the MSRP', async ({ page }) => {
    await expect(page.getByText('$12,999')).toBeVisible();
  });

  test('displays the category and year', async ({ page }) => {
    // Category label + year are on the same line, e.g. "Adventure • 2026"
    await expect(page.getByText(/2026/).first()).toBeVisible();
  });

  test('unknown slug redirects to the storefront', async ({ page }) => {
    await page.goto('/bikes/does-not-exist');
    await expect(page).toHaveURL('/', { timeout: 10_000 });
  });
});

// ---------------------------------------------------------------------------
// Image slider
// ---------------------------------------------------------------------------

test.describe('Bike detail — image slider', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(RALLY_URL);
    await waitForLiveSocket(page);
  });

  test('displays a bike image', async ({ page }) => {
    await expect(page.locator('#image-slider img')).toBeVisible();
  });

  /**
   * The counter, prev/next buttons, and dot indicators are only rendered by
   * Phoenix when the bike has > 1 image (inside an `if length > 1` block).
   * We use the "Next image" button as a cheap guard: if it's not present within
   * 2 s the bike has only one image and we skip rather than timing out.
   */
  async function hasMultipleImages(page: Page): Promise<boolean> {
    return page
      .locator('#image-slider button[aria-label="Next image"]')
      .isVisible({ timeout: 2_000 })
      .catch(() => false);
  }

  test('image counter shows 1 / N when multiple images exist', async ({ page }) => {
    if (!await hasMultipleImages(page)) test.skip(true, 'only one image — counter not rendered');

    // Counter text is e.g. "1 / 4". Use a loose regex since Phoenix may emit
    // whitespace around the interpolated integers.
    await expect(
      page.locator('#image-slider').getByText(/1\s*\/\s*\d+/)
    ).toBeVisible();
  });

  test('next-image button advances the counter', async ({ page }) => {
    if (!await hasMultipleImages(page)) test.skip(true, 'only one image — slider navigation not applicable');

    await page.getByRole('button', { name: 'Next image' }).click();
    await expect(
      page.locator('#image-slider').getByText(/2\s*\/\s*\d+/)
    ).toBeVisible();
  });

  test('prev-image wraps from first to last image', async ({ page }) => {
    if (!await hasMultipleImages(page)) test.skip(true, 'only one image — slider navigation not applicable');

    // Get total from the counter before clicking
    const raw = await page.locator('#image-slider').getByText(/1\s*\/\s*\d+/).textContent();
    const total = parseInt(raw?.split('/')[1].trim() ?? '1', 10);

    await page.getByRole('button', { name: 'Previous image' }).click();
    await expect(
      page.locator('#image-slider').getByText(new RegExp(`${total}\\s*\\/\\s*${total}`))
    ).toBeVisible();
  });

  test('dot indicators are rendered', async ({ page }) => {
    if (!await hasMultipleImages(page)) test.skip(true, 'only one image — dots not rendered for a single image');

    await expect(page.getByRole('button', { name: 'Go to image 1' })).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Spec tabs
// ---------------------------------------------------------------------------

test.describe('Bike detail — spec tabs', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto(RALLY_URL);
    await waitForLiveSocket(page);
  });

  test('Description tab is active by default', async ({ page }) => {
    // The Description tab button should carry the tab-active class
    await expect(page.locator('.tab.tab-active')).toBeVisible();
    // A quick-ask / marketing description text should be visible
    await expect(page.locator('.tab.tab-active')).toContainText('Description');
  });

  test('clicking Engine tab shows engine specs', async ({ page }) => {
    await page.getByRole('button', { name: /engine/i }).click();

    // Displacement label is present in the engine tab for all bikes
    await expect(page.getByText('Displacement')).toBeVisible();
    // The 800X Rally has a 799cc engine
    await expect(page.getByText('799cc').first()).toBeVisible();
  });

  test('Engine tab shows Transmission', async ({ page }) => {
    await page.getByRole('button', { name: /engine/i }).click();
    await expect(page.getByText('Transmission')).toBeVisible();
  });

  test('clicking Chassis tab shows chassis specs', async ({ page }) => {
    await page.getByRole('button', { name: /chassis/i }).click();
    // Front Suspension is present in chassis for the 800X Rally
    await expect(page.getByText('Front Suspension')).toBeVisible();
  });

  test('Chassis tab shows Dimensions section', async ({ page }) => {
    await page.getByRole('button', { name: /chassis/i }).click();
    await expect(page.getByText('Dimensions').first()).toBeVisible();
  });

  test('tabs switch content without page navigation', async ({ page }) => {
    await expect(page).toHaveURL(RALLY_URL);
    await page.getByRole('button', { name: /engine/i }).click();
    await expect(page).toHaveURL(RALLY_URL);
    await page.getByRole('button', { name: /chassis/i }).click();
    await expect(page).toHaveURL(RALLY_URL);
  });
});

// ---------------------------------------------------------------------------
// Navigation
// ---------------------------------------------------------------------------

test.describe('Bike detail — navigation', () => {
  test('storefront "View Details" link navigates to the correct detail page', async ({ page }) => {
    await page.goto('/');
    await waitForLiveSocket(page);

    await page.getByRole('link', { name: 'View Details' }).first().click();
    await expect(page).toHaveURL(/\/bikes\//, { timeout: 10_000 });
    await expect(page.getByRole('heading', { level: 1 })).toBeVisible();
  });

  test('page title matches the bike name navigated to', async ({ page }) => {
    await page.goto('/');
    await waitForLiveSocket(page);

    const firstCard = page.locator('article.card').first();
    const bikeName = await firstCard.locator('h2').first().textContent();
    await firstCard.getByRole('link', { name: 'View Details' }).click();
    await expect(page).toHaveURL(/\/bikes\//, { timeout: 10_000 });

    if (bikeName) {
      // The H1 on the detail page should contain the bike name (sans year prefix if any)
      const shortName = bikeName.replace(/^2026\s+(?:Kove\s+)?/i, '').trim();
      await expect(page.getByRole('heading', { level: 1 })).toContainText(shortName);
    }
  });
});

// ---------------------------------------------------------------------------
// Kovy chat panel — desktop viewport
// ---------------------------------------------------------------------------

test.describe('Bike detail — Kovy chat panel (desktop)', () => {
  test.use({ viewport: { width: 1280, height: 800 } });

  test.beforeEach(async ({ page }) => {
    await page.goto(RALLY_URL);
    await waitForLiveSocket(page);
  });

  test('chat panel header is visible', async ({ page }) => {
    await expect(page.getByRole('heading', { name: 'Kovy' })).toBeVisible();
    await expect(page.getByText('Your bike assistant')).toBeVisible();
  });

  test('context label references the bike name', async ({ page }) => {
    // The empty-state greeting says "Ask me anything about the <bike name>"
    await expect(page.getByText(/Ask me anything about the.*800X Rally/i)).toBeVisible();
  });

  test('displays the three quick-ask buttons', async ({ page }) => {
    await expect(page.getByText('vs KTM?')).toBeVisible();
    await expect(page.getByText('Maintenance?')).toBeVisible();
    await expect(page.getByText('Upgrades?')).toBeVisible();
  });

  test('chat input is enabled on load', async ({ page }) => {
    await expect(
      page.locator('#kovy-chat-form input[name="message"]')
    ).toBeEnabled();
  });

  test('chat input placeholder references this bike', async ({ page }) => {
    await expect(
      page.locator('#kovy-chat-form input[name="message"]')
    ).toHaveAttribute('placeholder', 'Ask about this bike...');
  });

  test('typing and submitting a message renders a user bubble', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('What is the seat height?');
    await input.press('Enter');

    await expect(
      page.locator('#kovy-chat-messages').getByText('What is the seat height?')
    ).toBeVisible({ timeout: 5_000 });
  });

  test('after submitting, the input is disabled while Kovy responds', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('What is the seat height?');
    await input.press('Enter');

    // Wait for user bubble — same LiveView diff as chat_loading: true
    await expect(
      page.locator('#kovy-chat-messages').getByText('What is the seat height?')
    ).toBeVisible({ timeout: 5_000 });

    await expect(input).toBeDisabled({ timeout: 5_000 });
    await expect(input).toHaveAttribute('placeholder', 'Kovy is thinking…');
  });

  test('clicking a quick-ask sends the full question', async ({ page }) => {
    await page.getByText('vs KTM?').click();

    await expect(
      page.locator('#kovy-chat-messages').getByText('How does this compare to a KTM?')
    ).toBeVisible({ timeout: 5_000 });
  });

  test('AI response is streamed back and rendered', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('Tell me about the engine');
    await input.press('Enter');

    await expect(
      page.locator('#kovy-chat-messages').getByText(/Kove offers/i)
    ).toBeVisible({ timeout: 15_000 });
  });

  test('input is re-enabled after the AI response completes', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('Tell me about the engine');
    await input.press('Enter');

    await expect(
      page.locator('#kovy-chat-messages').getByText(/Kove offers/i)
    ).toBeVisible({ timeout: 15_000 });
    await expect(input).toBeEnabled({ timeout: 5_000 });
  });

  test('can send a follow-up message', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    const messages = page.locator('#kovy-chat-messages');

    await input.fill('Tell me about the engine');
    await input.press('Enter');
    await expect(messages.getByText(/Kove offers/i)).toBeVisible({ timeout: 15_000 });

    await input.fill('How about the suspension?');
    await input.press('Enter');
    await expect(messages.getByText('How about the suspension?')).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Kovy chat FAB — mobile viewport
// ---------------------------------------------------------------------------

test.describe('Bike detail — Kovy chat FAB (mobile)', () => {
  test.use({ viewport: { width: 390, height: 844 } });

  test.beforeEach(async ({ page }) => {
    await page.goto(RALLY_URL);
    await waitForLiveSocket(page);
  });

  test('shows the floating action button', async ({ page }) => {
    await expect(page.locator('#kovy-chat-fab')).toBeVisible();
  });

  test('desktop chat panel is hidden on mobile', async ({ page }) => {
    const desktopHeading = page
      .locator('div.hidden.lg\\:block')
      .getByRole('heading', { name: 'Kovy' });
    await expect(desktopHeading).not.toBeVisible();
  });

  test('tapping the FAB opens the mobile chat drawer', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();

    await expect(page.locator('#kovy-chat-drawer')).toBeVisible({ timeout: 3_000 });
    await expect(page.locator('#kovy-chat-fab')).not.toBeVisible();
  });

  test('mobile drawer contains a chat input', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();

    await expect(
      page.locator('#kovy-chat-mobile-form input[name="message"]')
    ).toBeVisible({ timeout: 3_000 });
  });

  test('close button dismisses the mobile drawer', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();
    await expect(page.locator('#kovy-chat-drawer')).toBeVisible({ timeout: 3_000 });

    await page.locator('#kovy-chat-close').click();

    await expect(page.locator('#kovy-chat-drawer')).not.toBeVisible({ timeout: 3_000 });
    await expect(page.locator('#kovy-chat-fab')).toBeVisible({ timeout: 3_000 });
  });

  test('mobile chat sends a message and shows the user bubble', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();

    const input = page.locator('#kovy-chat-mobile-form input[name="message"]');
    await expect(input).toBeVisible({ timeout: 3_000 });
    await input.fill('What is the horsepower?');
    await input.press('Enter');

    await expect(
      page.locator('#kovy-chat-mobile-messages').getByText('What is the horsepower?')
    ).toBeVisible({ timeout: 5_000 });
  });

  test('mobile AI response is streamed back', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();

    const input = page.locator('#kovy-chat-mobile-form input[name="message"]');
    await expect(input).toBeVisible({ timeout: 3_000 });
    await input.fill('Tell me about the engine');
    await input.press('Enter');

    await expect(
      page.locator('#kovy-chat-mobile-messages').getByText(/Kove offers/i)
    ).toBeVisible({ timeout: 15_000 });
  });
});
