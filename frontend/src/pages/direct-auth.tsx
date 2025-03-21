import React from 'react';
import Head from 'next/head';
import Link from 'next/link';

// Static list of supported countries - no dependency on auth context
const COUNTRIES = [
  { id: 'usa-oidc', name: 'United States', flag: '🇺🇸' },
  { id: 'uk-oidc', name: 'United Kingdom', flag: '🇬🇧' },
  { id: 'canada-oidc', name: 'Canada', flag: '🇨🇦' },
  { id: 'australia-oidc', name: 'Australia', flag: '🇦🇺' },
  { id: 'newzealand-oidc', name: 'New Zealand', flag: '🇳🇿' }
];

export default function DirectAuthPage() {
  return (
    <>
      <Head>
        <title>Sign In - Choose Your Country</title>
        <meta name="description" content="Select your country to sign in" />
        <meta name="robots" content="noindex" />
      </Head>
      
      <div className="flex flex-col items-center justify-center min-h-screen bg-gray-100">
        <div className="bg-white p-8 rounded-lg shadow-md max-w-md w-full">
          <h1 className="text-2xl font-bold mb-6 text-center">Select Your Country</h1>
          <p className="text-gray-600 mb-6 text-center">
            Please select your country to continue to the appropriate login service.
          </p>
          
          <div className="space-y-3">
            {COUNTRIES.map((country) => (
              <Link 
                key={country.id}
                href={`/login/${country.id}`}
                className="flex items-center w-full p-4 border rounded-md hover:bg-gray-50 transition-colors"
              >
                <span className="text-2xl mr-3">{country.flag}</span>
                <span className="font-medium">{country.name}</span>
              </Link>
            ))}
          </div>
          
          <div className="mt-6 text-center">
            <Link
              href="/"
              className="text-blue-600 hover:text-blue-800 text-sm"
            >
              Return to Home
            </Link>
          </div>
        </div>
      </div>
    </>
  );
} 