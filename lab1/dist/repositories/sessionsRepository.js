"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.SessionsRepository = void 0;
class SessionsRepository {
    constructor(conn) {
        this.conn = conn;
    }
    async getAllSessions() {
        const { rows } = await this.conn.query('SELECT * FROM f1.v_sessions_extended');
        return rows;
    }
}
exports.SessionsRepository = SessionsRepository;
