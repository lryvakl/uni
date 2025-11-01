import { PoolClient } from 'pg';

export class ResultsRepository {
    constructor(private conn: PoolClient) {}

    async recordRaceResult(sessionId: number, driverId: number, constructorId: number, position: number) {
        await this.conn.query(
            'SELECT f1.sp_record_race_result($1,$2,$3,$4)',
            [sessionId, driverId, constructorId, position],
        );
    }
}
