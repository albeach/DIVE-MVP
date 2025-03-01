// mongodb/scripts/monitor.js
/**
 * MongoDB Monitoring Script for DIVE25
 * 
 * This script collects and displays MongoDB server statistics and metrics.
 * Run with: mongosh --file monitor.js
 */

// Configuration
const interval = 5000; // 5 seconds
const iterations = 12; // Run for 1 minute

// Print startup message
print(`MongoDB Monitoring Started at ${new Date().toISOString()}`);
print(`Collecting statistics every ${interval / 1000} seconds for ${iterations} iterations`);
print("----------------------------------------");

// Connect to admin database
const adminDb = db.getSiblingDB('admin');

// Main monitoring loop
for (let i = 0; i < iterations; i++) {
    try {
        // Get server status
        const serverStatus = adminDb.runCommand({ serverStatus: 1 });

        // Extract key metrics
        const metrics = {
            time: new Date().toISOString(),
            connections: serverStatus.connections.current,
            activeConnections: serverStatus.connections.active,
            opcounters: serverStatus.opcounters,
            memory: {
                resident: Math.round(serverStatus.mem.resident / 1024) + " GB",
                virtual: Math.round(serverStatus.mem.virtual / 1024) + " GB"
            },
            network: {
                bytesIn: serverStatus.network.bytesIn,
                bytesOut: serverStatus.network.bytesOut
            }
        };

        // Print metrics
        print(JSON.stringify(metrics, null, 2));
        print("----------------------------------------");

        // Wait for interval before next iteration
        if (i < iterations - 1) {
            sleep(interval);
        }
    } catch (err) {
        print(`Error collecting metrics: ${err.message}`);
    }
}

print(`MongoDB Monitoring Completed at ${new Date().toISOString()}`);