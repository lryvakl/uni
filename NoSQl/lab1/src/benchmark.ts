import { pool } from './db/pool'; 
import { connectMongo, disconnectMongo } from './db/mongo';
import { TelemetryModel } from './models/telemetry';

const SESSION_ID = 9999; 
const DRIVERS_COUNT = 20; 
const LAPS_COUNT = 50;   

const runBenchmark = async () => {

    await connectMongo();
    
    console.log(`\n STARTING BENCHMARK: ${DRIVERS_COUNT} drivers, ${LAPS_COUNT} laps each.`);
    console.log('--------------------------------------------------');

    // --- TEST 1: SQL WRITE ---
    console.time('SQL Write (INSERT 1000 rows)');
    const sqlClient = await pool.connect();
    try {
        await sqlClient.query('BEGIN');
        for (let d = 1; d <= DRIVERS_COUNT; d++) {
            for (let l = 1; l <= LAPS_COUNT; l++) {
                await sqlClient.query(
                    `INSERT INTO lap_times (session_id, driver_id, lap_number, sector_1, sector_2, sector_3, tyre_compound)
                     VALUES ($1, $2, $3, 24.5, 30.2, 19.8, 'SOFT')`,
                    [SESSION_ID, d, l]
                );
            }
        }
        await sqlClient.query('COMMIT');
    } catch (e) {
        await sqlClient.query('ROLLBACK');
        console.error(e);
    }
    sqlClient.release();
    console.timeEnd('SQL Write (INSERT 1000 rows)');

    // --- TEST 2: NoSQL WRITE ---
    console.time('NoSQL Write (INSERT 20 docs)');
    const mongoDocs = [];
    for (let d = 1; d <= DRIVERS_COUNT; d++) {
        const laps = [];
        for (let l = 1; l <= LAPS_COUNT; l++) {
            laps.push({ lap_number: l, sector_1: 24.5, sector_2: 30.2, sector_3: 19.8, tyre_compound: 'SOFT' });
        }
        mongoDocs.push({
            session_id: SESSION_ID,
            driver_id: d,
            car_setup: { wing: 5, engine: 'mode1' },
            laps: laps
        });
    }
    await TelemetryModel.insertMany(mongoDocs);
    console.timeEnd('NoSQL Write (INSERT 20 docs)');

    console.log('--------------------------------------------------');

    // --- TEST 3: SQL READ ---
    // Get the entire race history for one driver
    console.time('SQL Read (SELECT 50 rows)');
    await pool.query('SELECT * FROM lap_times WHERE session_id = $1 AND driver_id = $2', [SESSION_ID, 1]);
    console.timeEnd('SQL Read (SELECT 50 rows)');

    // --- TEST 4: NoSQL READ ---
    console.time('NoSQL Read (Find 1 doc)');
    await TelemetryModel.findOne({ session_id: SESSION_ID, driver_id: 1 });
    console.timeEnd('NoSQL Read (Find 1 doc)');

    console.log('\n Cleaning up test data...');
    await pool.query('DELETE FROM lap_times WHERE session_id = $1', [SESSION_ID]);
    await TelemetryModel.deleteMany({ session_id: SESSION_ID });

    await disconnectMongo();
    await pool.end();
};

runBenchmark().catch(console.error);