import { NextApiRequest, NextApiResponse } from 'next';
import fs from 'fs';
import path from 'path';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
    const { path: filePath } = req.query;

    if (!filePath || !Array.isArray(filePath)) {
        return res.status(404).json({ error: 'File not found' });
    }

    // Construct the full path to the static file
    const staticPath = filePath.join('/');
    let fullPath = path.join(process.cwd(), '.next', 'static', staticPath);

    // Special case for CSS files - look in the correct directory
    if (staticPath.startsWith('css/')) {
        fullPath = path.join(process.cwd(), '.next', 'static', staticPath);
    }

    try {
        // Check if file exists
        if (!fs.existsSync(fullPath)) {
            console.error(`File not found: ${fullPath}`);
            return res.status(404).json({ error: 'File not found' });
        }

        // Determine content type based on file extension
        const ext = path.extname(fullPath).toLowerCase();
        let contentType = 'text/plain';

        switch (ext) {
            case '.css':
                contentType = 'text/css';
                break;
            case '.js':
                contentType = 'application/javascript';
                break;
            case '.json':
                contentType = 'application/json';
                break;
            case '.png':
                contentType = 'image/png';
                break;
            case '.jpg':
            case '.jpeg':
                contentType = 'image/jpeg';
                break;
            case '.svg':
                contentType = 'image/svg+xml';
                break;
        }

        // Set CORS headers
        res.setHeader('Access-Control-Allow-Origin', '*');
        res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', '*');

        // Set content type and cache headers
        res.setHeader('Content-Type', contentType);
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');

        // Read and return the file
        const fileContent = fs.readFileSync(fullPath);
        res.status(200).send(fileContent);
    } catch (error) {
        console.error(`Error serving static file: ${error}`);
        res.status(500).json({ error: 'Internal server error' });
    }
} 