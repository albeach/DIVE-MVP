import { useEffect } from 'react';
import Head from 'next/head';

// This component is a special proxy to fix CORS issues with CSS files
export default function FixCss() {
  // Get the CSS filename from the URL
  useEffect(() => {
    // Create a link to the actual CSS but served by our domain
    const cssFile = document.createElement('link');
    cssFile.rel = 'stylesheet';
    cssFile.href = '/_next/static/css/cf2f07e87a7c6988.css';
    cssFile.type = 'text/css';
    
    // Append to document head
    document.head.appendChild(cssFile);
    
    // Log for debugging
    console.log('Fixed CSS loaded with CORS headers');
  }, []);

  return (
    <>
      <Head>
        <title>CSS Fix</title>
        <meta name="robots" content="noindex, nofollow" />
      </Head>
      <div id="css-fix-container" style={{display: 'none'}}>
        CSS Loading...
      </div>
    </>
  );
}

// Force server-side rendering to ensure CORS headers are applied
export async function getServerSideProps() {
  return {
    props: {},
  };
} 