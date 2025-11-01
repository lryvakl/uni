import { PoolClient } from 'pg';

export class SessionsRepository {
    constructor(private conn: PoolClient) {}

    async getAllSessions() {
        const { rows } = await this.conn.query('SELECT * FROM f1.v_sessions_extended');
        return rows;
    }
}
