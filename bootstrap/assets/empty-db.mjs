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
  const tables = await client.query("SELECT count(*)::int AS count FROM information_schema.tables WHERE table_schema = 'public' AND table_type = 'BASE TABLE'");
  if (tables.rows[0].count === 0) {
    console.log('empty');
  } else {
    const core = await client.query(`SELECT to_regclass('public."user"') AS users, to_regclass('public.property') AS properties, to_regclass('public.unit') AS units, to_regclass('public.role') AS roles`);
    if (Object.values(core.rows[0]).some(value => value === null)) throw new Error('Nonempty incompatible schema');
    console.log('ready');
  }
} catch (error) {
  console.error(`RDS preflight failed (${error.code || 'connection error'}). Check RDS availability, configuration and network access.`);
  process.exitCode = 1;
} finally {
  await client.end().catch(() => {});
}
