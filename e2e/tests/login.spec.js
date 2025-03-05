const { test, expect } = require('@playwright/test');
const {
    loginViaKeycloak,
    isAuthenticated,
    logout,
    TEST_USERNAME
} = require('./helpers/auth-helpers');
const Env = require('./helpers/environment');

test.describe('Login functionality', () => {
    test.beforeEach(async ({ page }) => {
        // Navigate to the login page before each test
        await page.goto(Env.getPageUrl('/login'));
    });

    test('should show login form when not authenticated', async ({ page }) => {
        // Verify the login form is visible (either our form or Keycloak's form)
        await expect(page.locator('form')).toBeVisible();
        await expect(page.getByRole('button', { name: /sign in|Log In|login/i })).toBeVisible();
    });

    test('should login successfully with helper function', async ({ page }) => {
        // Use our helper function to login
        await loginViaKeycloak(page);

        // Verify authentication status
        const isLoggedIn = await isAuthenticated(page);
        expect(isLoggedIn).toBeTruthy();

        // Verify user-specific content is visible after login
        await page.goto(Env.getPageUrl('/dashboard'));
        const welcomeText = page.getByText(new RegExp(`welcome.*${TEST_USERNAME}`, 'i'));
        await expect(welcomeText).toBeVisible();
    });

    test('should maintain session after navigation', async ({ page }) => {
        // Login first
        await loginViaKeycloak(page);

        // Verify we're authenticated
        expect(await isAuthenticated(page)).toBeTruthy();

        // Navigate to another page within the app
        await page.goto(Env.getPageUrl('/documents'));

        // Verify we're still logged in (not redirected to login)
        expect(await isAuthenticated(page)).toBeTruthy();
        await expect(page.locator('.user-info')).toBeVisible();
    });

    test('should be able to logout', async ({ page }) => {
        // Login first
        await loginViaKeycloak(page);

        // Verify we're authenticated
        expect(await isAuthenticated(page)).toBeTruthy();

        // Logout
        await logout(page);

        // Verify we are logged out
        expect(await isAuthenticated(page)).toBeFalsy();

        // Verify protected route redirects to login
        await page.goto(Env.getPageUrl('/documents'));
        expect(page.url()).toContain('login');
    });

    test('should handle token refresh', async ({ page }) => {
        // Login first
        await loginViaKeycloak(page);

        // Verify we're authenticated
        expect(await isAuthenticated(page)).toBeTruthy();

        // Simulate token refresh by manually clearing token but keeping refresh token
        await page.evaluate(() => {
            // Store refresh token
            const refreshToken = window.sessionStorage.getItem('kc_refreshToken');

            // Clear token
            window.sessionStorage.removeItem('kc_token');

            // Keep refresh token
            window.sessionStorage.setItem('kc_refreshToken', refreshToken);
        });

        // Navigate to a page that requires authentication
        await page.goto(Env.getPageUrl('/dashboard'));

        // After navigation, the token should be refreshed automatically
        // Wait a moment for the refresh to happen
        await page.waitForTimeout(2000);

        // Verify we're still authenticated
        expect(await isAuthenticated(page)).toBeTruthy();

        // Verify we can see user-specific content
        const welcomeText = page.getByText(new RegExp(`welcome.*${TEST_USERNAME}`, 'i'));
        await expect(welcomeText).toBeVisible();
    });
}); 