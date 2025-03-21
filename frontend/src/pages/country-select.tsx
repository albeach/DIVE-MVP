import React from 'react';
import { CountrySelector } from '@/components/auth/CountrySelector';
import { NextPage } from 'next';
import Head from 'next/head';

const CountrySelectPage: NextPage = () => {
  return (
    <>
      <Head>
        <title>Select Your Country - DIVE25</title>
        <meta name="description" content="Select your country to log in to DIVE25" />
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      </Head>
      <CountrySelector />
    </>
  );
};

export default CountrySelectPage; 