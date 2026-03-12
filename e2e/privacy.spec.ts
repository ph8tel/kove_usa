import { test, expect, type Page } from '@playwright/test';

async function waitForLiveSocket(page: Page): Promise<void> {
  await page.waitForFunction(
    () => (window as any).liveSocket?.isConnected() === true,
    { timeout: 10_000 }
  );
}

test.describe('Privacy Policy page', () => {
  test('footer has a Privacy Policy link', async ({ page }) => {
    await page.goto('/');
    await waitForLiveSocket(page);

    const footerPrivacyLink = page
      .locator('footer')
      .getByRole('link', { name: /privacy policy/i });

    await expect(footerPrivacyLink).toBeVisible();
    await expect(footerPrivacyLink).toHaveAttribute('href', '/privacy-policy');
  });

  test('privacy page exists and includes five main topics', async ({ page }) => {
    await page.goto('/privacy-policy');

    await expect(page).toHaveURL('/privacy-policy');
    await expect(page.getByRole('heading', { name: /privacy policy/i })).toBeVisible();

    await expect(
      page.getByRole('heading', { name: /^1\. Information We Collect$/i })
    ).toBeVisible();
    await expect(
      page.getByRole('heading', { name: /^2\. How We Use Your Information$/i })
    ).toBeVisible();
    await expect(
      page.getByRole('heading', { name: /^3\. Data Storage and Security$/i })
    ).toBeVisible();
    await expect(page.getByRole('heading', { name: /^4\. Your Rights$/i })).toBeVisible();
    await expect(
      page.getByRole('heading', { name: /^5\. Changes to This Policy$/i })
    ).toBeVisible();
  });
});
