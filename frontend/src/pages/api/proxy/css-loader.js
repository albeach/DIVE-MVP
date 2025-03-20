// frontend/src/pages/api/proxy/css-loader.js
export default function handler(req, res) {
    // Set CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Content-Type', 'application/javascript');
    res.setHeader('Cache-Control', 'public, max-age=3600'); // 1 hour cache

    // Handle OPTIONS request
    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    // Generate the loader script
    const script = `
  // DIVE25 CSS Loader - fixes CORS issues with CSS
  (function() {
    // The CSS file that's having CORS issues
    const cssFile = 'cf2f07e87a7c6988.css';
    
    // Create and append a link element for the CSS through our proxy
    function appendCSSLink() {
      // Create link element
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.type = 'text/css';
      
      // Use our proxy endpoint that adds CORS headers
      link.href = '${process.env.NEXT_PUBLIC_URL || 'https://dive25.local:8443'}/api/proxy/css?file=' + cssFile;
      
      // Append to document head
      document.head.appendChild(link);
      console.log('DIVE25: Fixed CSS CORS issue via proxy');
    }
    
    // If document is already loaded, append now
    if (document.readyState === 'complete' || document.readyState === 'interactive') {
      appendCSSLink();
    } else {
      // Otherwise wait for DOMContentLoaded
      document.addEventListener('DOMContentLoaded', appendCSSLink);
    }
  })();
  `;

    // Send the script
    res.status(200).send(script);
} 