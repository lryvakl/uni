"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.UnitOfWork = void 0;
const pool_1 = require("./pool");
class UnitOfWork {
    async start(userId) {
        this.client = await pool_1.pool.connect();
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
exports.UnitOfWork = UnitOfWork;
