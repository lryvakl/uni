import { Pool } from 'pg';

export const pool = new Pool({
    host: 'localhost',
    port: 5432,
    database: 'f1_events',
    user: 'postgres',
    password: 'postgres',
});
