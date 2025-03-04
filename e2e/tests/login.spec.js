const { test, expect } = require('@playwright/test');

test.describe('Login functionality', () => {
    test.beforeEach(async ({ page }) => {
        // Navigate to the login page before each test
        await page.goto('/login');
    });

    test('should show login form', async ({ page }) => {
        // Verify the login form is visible
        await expect(page.locator('form')).toBeVisible();
        await expect(page.getByLabel(/username/i)).toBeVisible();
        await expect(page.getByLabel(/password/i)).toBeVisible();
        await expect(page.getByRole('button', { name: /sign in/i })).toBeVisible();
    });

    test('should show error with invalid credentials', async ({ page }) => {
        // Fill in invalid credentials
        await page.getByLabel(/username/i).fill('invalid_user');
        await page.getByLabel(/password/i).fill('wrong_password');

        // Submit the form
        await page.getByRole('button', { name: /sign in/i }).click();

        // Wait for the error message and verify it
        const errorMessage = page.locator('.error-message');
        await expect(errorMessage).toBeVisible();
        await expect(errorMessage).toContainText(/invalid username or password/i);
    });

    test('should login successfully with valid credentials', async ({ page }) => {
        // Fill in valid credentials (these should match test environment credentials)
        await page.getByLabel(/username/i).fill('test-user');
        await page.getByLabel(/password/i).fill('test-password');

        // Submit the form
        await page.getByRole('button', { name: /sign in/i }).click();

        // Verify redirect to dashboard after successful login
        await expect(page).toHaveURL(/.*dashboard/);

        // Verify user-specific content is visible
        await expect(page.getByText(/welcome.*test-user/i)).toBeVisible();
    });

    test('should maintain session after login', async ({ page }) => {
        // Login with valid credentials
        await page.getByLabel(/username/i).fill('test-user');
        await page.getByLabel(/password/i).fill('test-password');
        await page.getByRole('button', { name: /sign in/i }).click();

        // Verify successful login
        await expect(page).toHaveURL(/.*dashboard/);

        // Navigate to another page within the app
        await page.goto('/documents');

        // Verify we're still logged in (not redirected to login)
        await expect(page).not.toHaveURL(/.*login/);
        await expect(page.locator('.user-info')).toBeVisible();
    });

    test('should be able to logout', async ({ page }) => {
        // Login first
        await page.getByLabel(/username/i).fill('test-user');
        await page.getByLabel(/password/i).fill('test-password');
        await page.getByRole('button', { name: /sign in/i }).click();

        // Click on logout button
        await page.getByRole('button', { name: /logout/i }).click();

        // Verify we are logged out and redirected to login page
        await expect(page).toHaveURL(/.*login/);

        // Verify protected route redirects to login
        await page.goto('/documents');
        await expect(page).toHaveURL(/.*login/);
    });
}); 