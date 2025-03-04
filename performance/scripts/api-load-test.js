import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';
import { SharedArray } from 'k6/data';

// Custom metrics
const errorRate = new Rate('error_rate');
const authTime = new Trend('auth_time');
const searchTime = new Trend('search_time');
const documentTime = new Trend('document_time');

// Test configuration
export const options = {
    scenarios: {
        constant_request_rate: {
            executor: 'constant-arrival-rate',
            rate: 50,
            timeUnit: '1m', // 50 iterations per minute, or ~0.83 per second
            duration: '2m',
            preAllocatedVUs: 10, // how many VUs to pre-allocate before test starts
            maxVUs: 50, // how many maximum VUs to allow during the test
        },
        stress_test: {
            executor: 'ramping-arrival-rate',
            startRate: 10,
            timeUnit: '1m',
            stages: [
                { duration: '1m', target: 50 }, // ramp up to 50 iterations per minute
                { duration: '2m', target: 150 }, // ramp up to 150 iterations per minute
                { duration: '1m', target: 50 }, // ramp down to 50 iterations per minute
                { duration: '30s', target: 0 }, // ramp down to 0
            ],
            preAllocatedVUs: 10,
            maxVUs: 200,
        },
    },
    thresholds: {
        'http_req_duration': ['p(95)<2000'], // 95% of requests should be below 2000ms
        'error_rate': ['rate<0.1'], // error rate should be less than 10%
        'auth_time': ['p(95)<1000'], // 95% of authentication requests should be below 1000ms
        'search_time': ['p(95)<1500'], // 95% of search requests should be below 1500ms
        'document_time': ['p(95)<1800'], // 95% of document retrieval requests should be below 1800ms
    },
};

// Load test data (simulating different search queries)
const searchTerms = new SharedArray('search terms', function () {
    return [
        'document',
        'report',
        'financial',
        'security',
        'classified',
        'annual',
        'quarterly',
        'analysis',
        'database',
        'system',
    ];
});

// Load test data (simulating different document IDs)
const documentIds = new SharedArray('document ids', function () {
    return [
        '60d21b4667d0d8992e610c85',
        '60d21b4667d0d8992e610c86',
        '60d21b4667d0d8992e610c87',
        '60d21b4667d0d8992e610c88',
        '60d21b4667d0d8992e610c89',
    ];
});

// Main test function
export default function () {
    // Get base URL from environment or use default
    const apiBaseUrl = __ENV.API_URL || 'http://localhost:3000';

    // Test authentication endpoint
    const authStart = new Date();
    let authRes = http.post(`${apiBaseUrl}/auth/login`, JSON.stringify({
        username: 'test-user',
        password: 'test-password',
    }), {
        headers: { 'Content-Type': 'application/json' },
    });

    authTime.add(new Date() - authStart);

    const success = check(authRes, {
        'login status is 200': (r) => r.status === 200,
        'has access token': (r) => r.json('accessToken') !== undefined,
    });

    errorRate.add(!success);

    if (!success) {
        console.log(`Authentication failed: ${authRes.status} ${authRes.body}`);
        sleep(1);
        return;
    }

    // Extract the token for subsequent requests
    const accessToken = authRes.json('accessToken');
    const headers = {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
    };

    // Test search endpoint
    const searchTerm = searchTerms[Math.floor(Math.random() * searchTerms.length)];
    const searchStart = new Date();
    const searchRes = http.get(`${apiBaseUrl}/documents/search?query=${searchTerm}`, { headers });
    searchTime.add(new Date() - searchStart);

    check(searchRes, {
        'search status is 200': (r) => r.status === 200,
        'search results exist': (r) => r.json('documents') !== undefined,
    });

    // Test document retrieval endpoint
    const documentId = documentIds[Math.floor(Math.random() * documentIds.length)];
    const documentStart = new Date();
    const documentRes = http.get(`${apiBaseUrl}/documents/${documentId}`, { headers });
    documentTime.add(new Date() - documentStart);

    check(documentRes, {
        'document retrieval status is 200': (r) => r.status === 200,
        'document data exists': (r) => r.json('document') !== undefined,
    });

    // Add some randomized think time between requests (100-500ms)
    sleep(Math.random() * 0.4 + 0.1);
} 