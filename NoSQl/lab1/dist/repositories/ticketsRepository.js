"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.TicketsRepository = void 0;
class TicketsRepository {
    constructor(conn) {
        this.conn = conn;
    }
    async buyTicket(ticketId, userId) {
        const { rows } = await this.conn.query('SELECT f1.sp_sell_ticket($1,$2) AS order_id', [ticketId, userId]);
        return rows[0].order_id;
    }
    async cancelOrder(orderId) {
        await this.conn.query('SELECT f1.sp_cancel_order($1)', [orderId]);
    }
}
exports.TicketsRepository = TicketsRepository;
