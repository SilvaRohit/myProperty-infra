import { readFileSync } from 'node:fs';
import pg from 'pg';

const client = new pg.Client({
  host: process.env.DATABASE_HOST,
  port: Number(process.env.DATABASE_PORT || 5432),
  database: process.env.DATABASE_NAME,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
  connectionTimeoutMillis: 10000,
  statement_timeout: 10000,
  ssl: {
    rejectUnauthorized: true,
    ca: readFileSync('/app/certs/global-bundle.pem', 'utf8')
  }
});

try {
  await client.connect();
  await client.query('SELECT 1');
  console.log('RDS connection and verified TLS succeeded.');
} catch (error) {
  console.error(`RDS preflight failed (${error.code || 'connection error'}). Check RDS availability, configuration and network access.`);
  process.exitCode = 1;
} finally {
  await client.end().catch(() => {});
}
