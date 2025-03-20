import fs from 'fs';
import path from 'path';

export default async function handler(req, res) {
    // Enable CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');
    // Always set the correct content type for CSS
    res.setHeader('Content-Type', 'text/css');
    res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

    // Handle OPTIONS request
    if (req.method === 'OPTIONS') {
        res.status(200).end();
        return;
    }

    try {
        // Get the CSS filename from the query parameter
        const cssFile = req.query.file || 'cf2f07e87a7c6988.css';

        // Log request for debugging
        console.log(`Proxying CSS file: ${cssFile}`);

        // Check for suspicious filenames to prevent directory traversal
        if (cssFile.includes('..') || !cssFile.endsWith('.css')) {
            console.error(`Security warning: Invalid CSS filename requested: ${cssFile}`);
            return res.status(400).send('/* Invalid CSS filename */');
        }

        // Construct paths to possible CSS file locations
        const cssLocations = [
            path.join(process.cwd(), '.next', 'static', 'css', cssFile),
            path.join(process.cwd(), 'public', 'css', cssFile),
            path.join(process.cwd(), 'styles', cssFile)
        ];

        // Try to find the CSS file in one of the locations
        let cssContent = null;
        let foundPath = null;

        for (const cssPath of cssLocations) {
            if (fs.existsSync(cssPath)) {
                foundPath = cssPath;
                cssContent = fs.readFileSync(cssPath, 'utf8');
                break;
            }
        }

        // If file was found, serve it
        if (cssContent) {
            console.log(`Found CSS file at: ${foundPath}`);
            res.status(200).send(cssContent);
            return;
        }

        // If file wasn't found anywhere, serve an empty CSS with a comment
        console.warn(`CSS file not found: ${cssFile}`);
        res.status(200).send(`/* CSS file ${cssFile} not found - serving empty CSS */`);
    } catch (error) {
        console.error('Error serving CSS proxy:', error);
        // Even for errors, keep the Content-Type as text/css
        res.status(500).send(`/* Error loading CSS file: ${error.message} */`);
    }
} 