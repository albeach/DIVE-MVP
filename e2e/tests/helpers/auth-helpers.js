/**
 * Authentication helpers for E2E tests
 * 
 * These helpers simplify authentication during E2E testing, using 
 * hardcoded defaults with environment variable overrides.
 */
const { default: fetch } = require('node-fetch');
const Env = require('./environment');

/**
 * Login function for Playwright tests
 * Attempts direct token API first, falls back to UI login
 * 
 * @param {Object} page - Playwright page object
 * @returns {Promise<void>}
 */
async function loginViaKeycloak(page) {
    console.log(`Logging in as user: ${Env.TEST_USERNAME}`);

    // Try to use direct token API first (faster than UI login)
    try {
        // Get a token directly from Keycloak
        const tokenResponse = await page.context().request.post(
            Env.getTokenUrl(),
            {
                form: {
                    grant_type: 'password',
                    client_id: Env.CLIENT_ID,
                    username: Env.TEST_USERNAME,
                    password: Env.TEST_PASSWORD,
                }
            }
        );

        if (tokenResponse.ok()) {
            const tokenData = await tokenResponse.json();

            // Store token in session storage
            await page.evaluate((data) => {
                window.sessionStorage.setItem('kc_token', data.access_token);
                window.sessionStorage.setItem('kc_refreshToken', data.refresh_token);
            }, tokenData);

            console.log('Successfully obtained token via API');

            // Refresh the page to apply the token
            await page.reload();
            await page.waitForTimeout(1000);
            return;
        }
    } catch (error) {
        console.log('Direct token API failed, falling back to UI login');
    }

    // Fallback to UI login
    console.log('Using UI login flow');
    await page.goto(Env.getPageUrl('/login'));

    // Wait for redirect to Keycloak
    await page.waitForURL(url => url.toString().includes('keycloak') || url.toString().includes('auth/realms'),
        { timeout: Env.STANDARD_TIMEOUT });

    // Fill in username and password
    await page.fill('input[id="username"]', Env.TEST_USERNAME);
    await page.fill('input[id="password"]', Env.TEST_PASSWORD);

    // Click login button
    await page.click('input[type="submit"]');

    // Wait for redirect back to the application
    await page.waitForURL(url => !url.toString().includes('keycloak') && !url.toString().includes('auth/realms'),
        { timeout: Env.STANDARD_TIMEOUT });

    console.log('Successfully logged in via UI');
}

/**
 * Check if user is authenticated
 * @param {Object} page - Playwright page object 
 * @returns {Promise<boolean>} - True if authenticated
 */
async function isAuthenticated(page) {
    return page.evaluate(() => {
        return window.sessionStorage.getItem('kc_token') !== null;
    });
}

/**
 * Get authentication token from session storage
 * @param {Object} page - Playwright page object
 * @returns {Promise<string|null>} - Authentication token or null
 */
async function getAuthToken(page) {
    return page.evaluate(() => {
        return window.sessionStorage.getItem('kc_token');
    });
}

/**
 * Make authenticated API request
 * @param {Object} page - Playwright page object
 * @param {string} endpoint - API endpoint (without base URL)
 * @param {Object} options - Fetch options
 * @returns {Promise<Object>} - API response
 */
async function authenticatedApiRequest(page, endpoint, options = {}) {
    const token = await getAuthToken(page);
    if (!token) {
        throw new Error('No authentication token available');
    }

    const url = Env.getApiUrl(endpoint);

    const response = await page.context().request.fetch(url, {
        ...options,
        headers: {
            ...options.headers,
            'Authorization': `Bearer ${token}`
        }
    });

    return {
        status: response.status(),
        data: await response.json().catch(() => null),
        headers: response.headers(),
        ok: response.ok()
    };
}

/**
 * Logout function for Playwright tests
 * @param {Object} page - Playwright page object
 * @returns {Promise<void>}
 */
async function logout(page) {
    // Clear session storage
    await page.evaluate(() => {
        window.sessionStorage.removeItem('kc_token');
        window.sessionStorage.removeItem('kc_refreshToken');
    });

    // Go to logout endpoint
    await page.goto(Env.getPageUrl('/api/auth/logout'));

    // Wait for redirect to login page
    await page.waitForURL(url => url.toString().includes('login'), { timeout: Env.STANDARD_TIMEOUT });
}

module.exports = {
    loginViaKeycloak,
    isAuthenticated,
    getAuthToken,
    authenticatedApiRequest,
    logout,
    TEST_USERNAME: Env.TEST_USERNAME,
    TEST_PASSWORD: Env.TEST_PASSWORD
}; 