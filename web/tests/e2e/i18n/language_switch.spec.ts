import { test, expect } from "@playwright/test";

/**
 * 한국어 i18n 언어 전환 테스트
 * 로그인 후 사이드바 텍스트 확인, 언어 전환 버튼 클릭, 한국어 전환 확인, 새로고침 후 유지 확인
 */
test.describe("Language Switcher (i18n)", () => {
  test.use({ storageState: { cookies: [], origins: [] } }); // fresh session, no pre-auth

  test("should switch UI to Korean and persist after refresh", async ({
    page,
  }) => {
    // ── Step 1: Login ──────────────────────────────────────────────────────────
    await page.goto("/auth/login");
    await page.waitForLoadState("networkidle");

    await page.getByTestId("email").fill("a@example.com");
    await page.getByTestId("password").fill("password1");
    await page.screenshot({
      path: "output/playwright/i18n-01-login-form.png",
      fullPage: false,
    });

    await page.getByRole("button", { name: /sign in/i }).click();
    await page.waitForURL(/\/app/, { timeout: 15000 });
    await page.waitForLoadState("networkidle");

    // ── Step 2: Verify English sidebar ────────────────────────────────────────
    await expect(
      page.getByTestId("AppSidebar/new-session")
    ).toBeVisible({ timeout: 10000 });

    await expect(page.getByTestId("AppSidebar/new-session")).toContainText(
      "New Session"
    );
    await page.screenshot({
      path: "output/playwright/i18n-02-sidebar-english.png",
      fullPage: false,
    });

    // ── Step 3: Open user avatar popover ──────────────────────────────────────
    const userDropdown = page.locator("#onyx-user-dropdown");
    await expect(userDropdown).toBeVisible({ timeout: 5000 });
    await userDropdown.click();

    // Wait for popover to appear
    await page.waitForSelector("text=User Settings", { timeout: 5000 });
    await page.screenshot({
      path: "output/playwright/i18n-03-user-popover.png",
      fullPage: false,
    });

    // ── Step 4: Click language switcher (globe icon / EN / KO) ────────────────
    // The LanguageSwitcher renders as a LineItem with globe icon showing "EN / KO".
    // Note: Truncated component renders text twice (visible + hidden for width measurement),
    // so we filter to the first (visible) occurrence.
    const langSwitcher = page
      .getByRole("button", { name: /EN\s*\/\s*KO/ })
      .first();
    await expect(langSwitcher).toBeVisible({ timeout: 5000 });
    await langSwitcher.click();

    // Wait for page to refresh with Korean locale
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(1000); // allow React refresh to settle

    // ── Step 5: Verify Korean sidebar text ────────────────────────────────────
    await expect(
      page.getByTestId("AppSidebar/new-session")
    ).toBeVisible({ timeout: 10000 });

    await expect(page.getByTestId("AppSidebar/new-session")).toContainText(
      "새 세션"
    );
    await page.screenshot({
      path: "output/playwright/i18n-04-sidebar-korean.png",
      fullPage: false,
    });

    // ── Step 6: Refresh and verify Korean persists ────────────────────────────
    await page.reload();
    await page.waitForLoadState("networkidle");

    await expect(
      page.getByTestId("AppSidebar/new-session")
    ).toBeVisible({ timeout: 10000 });
    await expect(page.getByTestId("AppSidebar/new-session")).toContainText(
      "새 세션"
    );
    await page.screenshot({
      path: "output/playwright/i18n-05-after-refresh-korean.png",
      fullPage: false,
    });

    // ── Step 7: Switch back to English ────────────────────────────────────────
    const userDropdown2 = page.locator("#onyx-user-dropdown");
    await userDropdown2.click();
    await page.waitForSelector("text=사용자 설정", { timeout: 5000 });

    const langSwitcherKo = page
      .getByRole("button", { name: /KO\s*\/\s*EN/ })
      .first();
    await expect(langSwitcherKo).toBeVisible({ timeout: 5000 });
    await langSwitcherKo.click();

    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(1000);

    await expect(
      page.getByTestId("AppSidebar/new-session")
    ).toContainText("New Session", { timeout: 10000 });
    await page.screenshot({
      path: "output/playwright/i18n-06-back-to-english.png",
      fullPage: false,
    });
  });
});
