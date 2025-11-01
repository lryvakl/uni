import { UnitOfWork } from './db/unitOfWork';
import { SessionsRepository } from './repositories/sessionsRepository';
import { ResultsRepository } from './repositories/resultsRepository';
import { TicketsRepository } from './repositories/ticketsRepository';
import {pool} from "./db/pool";


async function resetTestData() {
    const client = await pool.connect();
    try {
        await client.query('BEGIN');
        await client.query('DELETE FROM f1.order_items;');
        await client.query('DELETE FROM f1.orders;');
        await client.query('UPDATE f1.tickets SET is_sold = FALSE;');
        await client.query('COMMIT');
    } catch (err) {
        await client.query('ROLLBACK');
        console.error('Reset failed:', err);
    } finally {
        client.release();
    }
}

async function main() {
    await resetTestData();
    const uow = new UnitOfWork();

    try {
        await uow.start(1); // set_app_user(1)

        const sessionRepo = new SessionsRepository(uow.getConnection());
        const resultsRepo = new ResultsRepository(uow.getConnection());
        const ticketsRepo = new TicketsRepository(uow.getConnection());

        // 1) SELECT через View
        console.log(await sessionRepo.getAllSessions());

        // 2) INSERT через Stored Procedure
        await resultsRepo.recordRaceResult(1, 1, 1, 1);



        // 3) Продаж квитка через Stored Procedure
        const orderId = await ticketsRepo.buyTicket(1, 1);
        console.log('Order created:', orderId);

        await uow.commit();
        console.log('Transaction committed');
    } catch (error) {
        console.error('Error:', error);
        await uow.rollback();
    }
}

main();
