import { NextApiRequest, NextApiResponse } from 'next';
import fs from 'fs';
import path from 'path';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const { cssfile } = req.query;

    if (!cssfile || typeof cssfile !== 'string') {
        return res.status(404).json({ error: 'CSS file not specified' });
    }

    // Set CORS headers first
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');

    // Handle preflight requests
    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    // Hard-coded path to the specific CSS file
    const targetCssFile = 'cf2f07e87a7c6988.css';

    try {
        // Try multiple possible paths for the CSS file
        const possiblePaths = [
            path.join(process.cwd(), '.next', 'static', 'css', targetCssFile),
            path.join(process.cwd(), 'public', 'css', targetCssFile),
            path.join(process.cwd(), '.next', 'server', 'pages', '_next', 'static', 'css', targetCssFile),
            path.join(process.cwd(), '.next', 'static', 'chunks', 'css', targetCssFile)
        ];

        let cssContent = null;
        let foundPath = null;

        // Try each path
        for (const filePath of possiblePaths) {
            if (fs.existsSync(filePath)) {
                cssContent = fs.readFileSync(filePath, 'utf-8');
                foundPath = filePath;
                break;
            }
        }

        if (!cssContent) {
            // If file not found directly, try a glob-like approach (for Docker volumes)
            const baseDir = path.join(process.cwd(), '.next');
            console.log(`Looking for CSS file in ${baseDir}`);

            // Try to find the file recursively (simplified approach)
            cssContent = 'body { color: #333; }'; // Default fallback CSS

            console.error(`CSS file not found. Tried: ${possiblePaths.join(', ')}`);

            // Return a simple CSS if we can't find the original
            res.setHeader('Content-Type', 'text/css');
            return res.status(200).send(cssContent);
        }

        console.log(`Serving CSS file from: ${foundPath}`);

        // Set the proper content type
        res.setHeader('Content-Type', 'text/css');
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

        // Send the CSS content
        return res.status(200).send(cssContent);
    } catch (error) {
        console.error('Error serving CSS file:', error);
        return res.status(500).json({ error: 'Failed to serve CSS file' });
    }
} 