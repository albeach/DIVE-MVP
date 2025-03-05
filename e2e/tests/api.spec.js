/**
 * API integration tests
 */
const { test, expect } = require('@playwright/test');
const {
    loginViaKeycloak,
    isAuthenticated,
    authenticatedApiRequest
} = require('./helpers/auth-helpers');
const Env = require('./helpers/environment');

test.describe('API integration tests', () => {
    test.beforeEach(async ({ page }) => {
        // Login before each test
        await loginViaKeycloak(page);

        // Ensure we're authenticated
        const isLoggedIn = await isAuthenticated(page);
        expect(isLoggedIn).toBeTruthy();
    });

    test('should fetch current user profile', async ({ page }) => {
        // Make authenticated request to the user profile endpoint
        const response = await authenticatedApiRequest(
            page,
            Env.API_ENDPOINTS.USERS + '/me'
        );

        // Verify successful response
        expect(response.status).toBe(200);
        expect(response.ok).toBeTruthy();

        // Verify response data
        expect(response.data).toHaveProperty('username');
        expect(response.data).toHaveProperty('email');
    });

    test('should fetch documents list', async ({ page }) => {
        // Make authenticated request to documents endpoint
        const response = await authenticatedApiRequest(
            page,
            Env.API_ENDPOINTS.DOCUMENTS
        );

        // Verify successful response
        expect(response.status).toBe(200);
        expect(response.ok).toBeTruthy();

        // Verify response data is an array
        expect(Array.isArray(response.data)).toBeTruthy();
    });

    test('should validate authorization headers', async ({ page }) => {
        // Make authenticated request to health endpoint (which should be public)
        const publicResponse = await page.context().request.get(
            Env.getApiUrl(Env.API_ENDPOINTS.HEALTH)
        );

        // Verify public endpoint works without auth
        expect(publicResponse.status()).toBe(200);

        // Attempt to access protected endpoint without auth
        const protectedNoAuthResponse = await page.context().request.get(
            Env.getApiUrl(Env.API_ENDPOINTS.USERS + '/me'),
            { ignoreHTTPSErrors: true }
        );

        // Should be unauthorized
        expect(protectedNoAuthResponse.status()).toBe(401);

        // Now try with auth
        const protectedWithAuthResponse = await authenticatedApiRequest(
            page,
            Env.API_ENDPOINTS.USERS + '/me'
        );

        // Should succeed
        expect(protectedWithAuthResponse.status).toBe(200);
    });

    test('should return token expiration warning headers', async ({ page }) => {
        // Simulate token about to expire by modifying API response
        await page.route(
            url => url.toString().includes(Env.API_ENDPOINTS.USERS),
            async route => {
                const response = await route.fetch();
                const headers = response.headers();

                // Add token expiration headers
                headers['X-Token-Expiring'] = 'true';
                headers['X-Token-Expires-In'] = '120';

                await route.fulfill({
                    response,
                    headers
                });
            }
        );

        // Make authenticated request
        const response = await authenticatedApiRequest(
            page,
            Env.API_ENDPOINTS.USERS + '/me'
        );

        // Verify headers are present
        expect(response.headers['x-token-expiring']).toBe('true');
        expect(response.headers['x-token-expires-in']).toBe('120');
    });
}); 