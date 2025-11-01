import { PoolClient } from 'pg';
import { pool } from './pool';

export class UnitOfWork {
    private client!: PoolClient;

    async start(userId: number) {
        this.client = await pool.connect();
        await this.client.query('BEGIN');
        await this.client.query('SELECT f1.set_app_user($1)', [userId]);
    }

    async commit() {
        await this.client.query('COMMIT');
        this.client.release();
    }

    async rollback() {
        await this.client.query('ROLLBACK');
        this.client.release();
    }

    getConnection() {
        return this.client;
    }
}
