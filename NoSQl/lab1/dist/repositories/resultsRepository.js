"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.ResultsRepository = void 0;
class ResultsRepository {
    constructor(conn) {
        this.conn = conn;
    }
    async recordRaceResult(sessionId, driverId, constructorId, position) {
        await this.conn.query('SELECT f1.sp_record_race_result($1,$2,$3,$4)', [sessionId, driverId, constructorId, position]);
    }
}
exports.ResultsRepository = ResultsRepository;
