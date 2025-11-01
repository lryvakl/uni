import { PoolClient } from 'pg';

export class TicketsRepository {
    constructor(private conn: PoolClient) {}

    async buyTicket(ticketId: number, userId: number) {
        const { rows } = await this.conn.query(
            'SELECT f1.sp_sell_ticket($1,$2) AS order_id',
            [ticketId, userId],
        );
        return rows[0].order_id;
    }

    async cancelOrder(orderId: number) {
        await this.conn.query(
            'SELECT f1.sp_cancel_order($1)',
            [orderId]
        );
    }
}
