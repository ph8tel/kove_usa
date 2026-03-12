import { test, expect, type Page } from '@playwright/test';

/**
 * Kove Moto USA — Storefront / Landing Page (/)
 *
 * These tests cover the public catalog page which renders:
 *  - A hero section with the brand heading
 *  - A 2-column grid of 6 bike cards
 *  - A desktop Kovy chat panel (right column, visible at ≥ lg breakpoint)
 *  - A mobile FAB that opens a full-screen chat drawer
 *
 * The Groq and OpenAI API calls are intercepted by the local mock server
 * (e2e/support/mock-api-server.cjs) so no real API keys are needed.
 */

/**
 * Wait for the Phoenix LiveSocket to complete its WebSocket handshake.
 *
 * This is necessary before clicking <.link navigate> links or submitting chat
 * forms. LiveSocket attaches a document-level click handler that calls
 * e.preventDefault() on data-phx-link elements regardless of connection state,
 * so if the socket hasn't connected yet the click is silently swallowed and the
 * browser never navigates.
 */
async function waitForLiveSocket(page: Page): Promise<void> {
  await page.waitForFunction(
    () => (window as any).liveSocket?.isConnected() === true,
    { timeout: 10_000 }
  );
}

// ---------------------------------------------------------------------------
// Page structure
// ---------------------------------------------------------------------------

test.describe('Storefront — page structure', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForLiveSocket(page);
  });

  test('has the correct page title', async ({ page }) => {
    await expect(page).toHaveTitle(/Kove Moto USA/i);
  });

  test('displays the hero heading', async ({ page }) => {
    const h1 = page.getByRole('heading', { level: 1 });
    await expect(h1).toBeVisible();
    await expect(h1).toContainText('KOVE MOTO');
    await expect(h1).toContainText('USA');
  });

  test('displays the demo subtitle', async ({ page }) => {
    await expect(
      page.getByText('Demo of AI chat assistant for Gary Goodwin')
    ).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Bike grid
// ---------------------------------------------------------------------------

test.describe('Storefront — bike grid', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForLiveSocket(page);
  });

  test('shows exactly 6 bike cards', async ({ page }) => {
    await expect(page.locator('article.card')).toHaveCount(6);
  });

  test('every card has a "View Details" link', async ({ page }) => {
    await expect(page.getByRole('link', { name: 'View Details' })).toHaveCount(6);
  });

  test('displays the 800X Rally', async ({ page }) => {
    await expect(page.getByText('2026 Kove 800X Rally')).toBeVisible();
  });

  test('displays the 800X Pro', async ({ page }) => {
    await expect(page.getByText('2026 Kove 800X Pro')).toBeVisible();
  });

  test('displays the 450 Rally Pro Off-Road', async ({ page }) => {
    await expect(page.getByText('2026 Kove 450 Rally Pro Off-Road')).toBeVisible();
  });

  test('displays the 450 Rally Street Legal', async ({ page }) => {
    // The product name in the DB comes from bijes.json: "2026 450 Rally Street Legal"
    await expect(page.getByText(/450 Rally Street Legal/)).toBeVisible();
  });

  test('displays the MX450', async ({ page }) => {
    await expect(page.getByText('2026 Kove MX450')).toBeVisible();
  });

  test('displays the MX250', async ({ page }) => {
    await expect(page.getByText('2026 Kove MX250')).toBeVisible();
  });

  test('"View Details" hrefs point to /bikes/:slug', async ({ page }) => {
    const firstHref = await page
      .getByRole('link', { name: 'View Details' })
      .first()
      .getAttribute('href');
    expect(firstHref).toMatch(/^\/bikes\//);
  });

  test('clicking "View Details" navigates to the bike detail page', async ({ page }) => {
    await page.getByRole('link', { name: 'View Details' }).first().click();
    await expect(page).toHaveURL(/\/bikes\//, { timeout: 15_000 });
  });

  test('bike cards show the engine displacement', async ({ page }) => {
    // The 800X Rally card should show "799cc"
    await expect(page.getByText(/799cc/).first()).toBeVisible();
  });

  test('bike cards show prices in dollar format', async ({ page }) => {
    // At least one card should show a formatted MSRP like "$12,999"
    await expect(page.getByText(/\$\d{1,3}(,\d{3})*/).first()).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Kovy chat panel — desktop viewport
// ---------------------------------------------------------------------------

test.describe('Storefront — Kovy chat panel (desktop)', () => {
  // The desktop chat panel is only visible at ≥ lg (1024 px).
  test.use({ viewport: { width: 1280, height: 800 } });

  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForLiveSocket(page);
  });

  test('chat panel header is visible', async ({ page }) => {
    await expect(page.getByRole('heading', { name: 'Kovy' })).toBeVisible();
    await expect(page.getByText('Your bike assistant')).toBeVisible();
  });

  test('displays all three quick-ask buttons', async ({ page }) => {
    await expect(page.getByText('Best for beginners?')).toBeVisible();
    await expect(page.getByText('Compare models')).toBeVisible();
    await expect(page.getByText('Off-road pick?')).toBeVisible();
  });

  test('chat input is enabled on load', async ({ page }) => {
    await expect(
      page.locator('#kovy-chat-form input[name="message"]')
    ).toBeEnabled();
  });

  test('typing and submitting a message renders a user bubble', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('What is the lightest Kove?');
    await input.press('Enter');

    // The user bubble is rendered synchronously when the LiveView processes the
    // send_message event — before any AI response. Scoped to the desktop
    // messages container because submitting opens chat_open=true which renders
    // an identical hidden mobile drawer in the DOM at the same time.
    await expect(
      page.locator('#kovy-chat-messages').getByText('What is the lightest Kove?')
    ).toBeVisible({ timeout: 5_000 });
  });

  test('after submitting, the input is disabled while Kovy responds', async ({
    page,
  }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('What is the lightest Kove?');
    await input.press('Enter');

    // The user bubble and chat_loading=true are set in the SAME LiveView diff.
    // Waiting for the bubble to appear guarantees disabled is already in effect.
    await expect(
      page.locator('#kovy-chat-messages').getByText('What is the lightest Kove?')
    ).toBeVisible({ timeout: 5_000 });

    // The mock server holds the stream open for 3 s before sending the first
    // token, so the window here is at least 3 seconds wide.
    await expect(input).toBeDisabled({ timeout: 5_000 });
    await expect(input).toHaveAttribute('placeholder', 'Kovy is thinking…');
  });

  test('clicking a quick-ask sends the full prefilled question', async ({ page }) => {
    await page.getByText('Best for beginners?').click();

    // The full message text (not just the label) should appear as a user bubble.
    // Scoped to the desktop container to avoid matching the hidden mobile drawer.
    await expect(
      page.locator('#kovy-chat-messages').getByText('Which Kove bike is best for a beginner?')
    ).toBeVisible({ timeout: 5_000 });
  });

  test('AI response is streamed back and rendered', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('Tell me about the lineup');
    await input.press('Enter');

    // Wait for text from the mock server's canned response to appear.
    // Scoped to the desktop container to avoid the hidden mobile drawer duplicate.
    await expect(
      page.locator('#kovy-chat-messages').getByText(/Kove offers/i)
    ).toBeVisible({ timeout: 15_000 });
  });

  test('input is re-enabled after the AI response completes', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    await input.fill('Tell me about the lineup');
    await input.press('Enter');

    // After the mock stream finishes the input should be enabled again.
    // Scoped to avoid the hidden mobile drawer duplicate.
    await expect(
      page.locator('#kovy-chat-messages').getByText(/Kove offers/i)
    ).toBeVisible({ timeout: 15_000 });
    await expect(input).toBeEnabled({ timeout: 5_000 });
  });

  test('can send a follow-up message after the first response', async ({ page }) => {
    const input = page.locator('#kovy-chat-form input[name="message"]');
    const messages = page.locator('#kovy-chat-messages');

    await input.fill('Tell me about the lineup');
    await input.press('Enter');
    await expect(messages.getByText(/Kove offers/i)).toBeVisible({ timeout: 15_000 });

    await input.fill('Which one has more power?');
    await input.press('Enter');
    await expect(messages.getByText('Which one has more power?')).toBeVisible();
  });
});

// ---------------------------------------------------------------------------
// Kovy chat FAB — mobile viewport
// ---------------------------------------------------------------------------

test.describe('Storefront — Kovy chat FAB (mobile)', () => {
  // iPhone 14 Pro dimensions — the desktop chat panel is hidden here
  test.use({ viewport: { width: 390, height: 844 } });

  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    await waitForLiveSocket(page);
  });

  test('shows the floating action button', async ({ page }) => {
    await expect(page.locator('#kovy-chat-fab')).toBeVisible();
  });

  test('desktop chat panel is hidden on mobile', async ({ page }) => {
    // The heading "Kovy" lives inside the hidden-on-mobile container, so it
    // should not be visible at this viewport width.
    const desktopHeading = page
      .locator('div.hidden.lg\\:block')
      .getByRole('heading', { name: 'Kovy' });
    await expect(desktopHeading).not.toBeVisible();
  });

  test('tapping the FAB opens the mobile chat drawer', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();

    await expect(page.locator('#kovy-chat-drawer')).toBeVisible({ timeout: 3_000 });
    // FAB should disappear once the drawer is open
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
    // FAB should reappear after closing
    await expect(page.locator('#kovy-chat-fab')).toBeVisible({ timeout: 3_000 });
  });

  test('mobile chat sends a message and shows the user bubble', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();

    const input = page.locator('#kovy-chat-mobile-form input[name="message"]');
    await expect(input).toBeVisible({ timeout: 3_000 });
    await input.fill('Best bike for off-road?');
    await input.press('Enter');

    // Same reasoning as the desktop test: scoped to the mobile container and
    // using toBeVisible's built-in polling instead of toBeDisabled.
    await expect(
      page.locator('#kovy-chat-mobile-messages').getByText('Best bike for off-road?')
    ).toBeVisible({ timeout: 5_000 });
  });

  test('mobile AI response is streamed back', async ({ page }) => {
    await page.locator('#kovy-chat-fab').click();

    const input = page.locator('#kovy-chat-mobile-form input[name="message"]');
    await expect(input).toBeVisible({ timeout: 3_000 });
    await input.fill('Tell me about the lineup');
    await input.press('Enter');

    // Scope to the mobile messages container.
    await expect(
      page.locator('#kovy-chat-mobile-messages').getByText(/Kove offers/i)
    ).toBeVisible({ timeout: 15_000 });
  });
});
