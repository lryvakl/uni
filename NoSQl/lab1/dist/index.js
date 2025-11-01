"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const unitOfWork_1 = require("./db/unitOfWork");
const sessionsRepository_1 = require("./repositories/sessionsRepository");
const resultsRepository_1 = require("./repositories/resultsRepository");
const ticketsRepository_1 = require("./repositories/ticketsRepository");
const pool_1 = require("./db/pool");
async function resetTestData() {
    const client = await pool_1.pool.connect();
    try {
        await client.query('BEGIN');
        await client.query('DELETE FROM f1.order_items;');
        await client.query('DELETE FROM f1.orders;');
        await client.query('UPDATE f1.tickets SET is_sold = FALSE;');
        await client.query('COMMIT');
    }
    catch (err) {
        await client.query('ROLLBACK');
        console.error('Reset failed:', err);
    }
    finally {
        client.release();
    }
}
async function main() {
    await resetTestData();
    const uow = new unitOfWork_1.UnitOfWork();
    try {
        await uow.start(1); // set_app_user(1)
        const sessionRepo = new sessionsRepository_1.SessionsRepository(uow.getConnection());
        const resultsRepo = new resultsRepository_1.ResultsRepository(uow.getConnection());
        const ticketsRepo = new ticketsRepository_1.TicketsRepository(uow.getConnection());
        // 1) SELECT через View
        console.log(await sessionRepo.getAllSessions());
        // 2) INSERT через Stored Procedure
        await resultsRepo.recordRaceResult(1, 1, 1, 1);
        // 3) Продаж квитка через Stored Procedure
        const orderId = await ticketsRepo.buyTicket(1, 1);
        console.log('Order created:', orderId);
        await uow.commit();
        console.log('Transaction committed');
    }
    catch (error) {
        console.error('Error:', error);
        await uow.rollback();
    }
}
main();
