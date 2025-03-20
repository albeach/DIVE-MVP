import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(request: NextRequest) {
    // Get the response
    const response = NextResponse.next();

    // Add CORS headers to all responses
    response.headers.set('Access-Control-Allow-Origin', '*');
    response.headers.set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS, PUT, PATCH, DELETE');
    response.headers.set('Access-Control-Allow-Headers', '*');

    // Special handling for CSS files
    if (request.nextUrl.pathname.includes('/_next/static/css/')) {
        console.log(`[Middleware] Adding CORS headers to CSS file: ${request.nextUrl.pathname}`);
        response.headers.set('Content-Type', 'text/css');
        response.headers.set('Cache-Control', 'public, max-age=31536000, immutable');
    }

    return response;
}

// Match all requests
export const config = {
    matcher: [
        // Match all except API routes
        '/((?!api/|_next/static/|favicon.ico).*)',
        // Match static files specifically 
        '/_next/static/:path*',
    ],
}; 