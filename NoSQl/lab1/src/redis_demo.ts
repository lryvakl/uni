import { connectRedis, disconnectRedis } from './db/redis';

const runRedisDemo = async () => {
    const client = await connectRedis();
    const LEADERBOARD_KEY = 'season_2025_drivers';

    console.log('\n --- REDIS LIVE LEADERBOARD DEMO ---');

    // 1. INSERT (ZADD)
    // Adding drivers with their current points
    console.log('1. Updating points...');
    await client.zAdd(LEADERBOARD_KEY, [
        { score: 350, value: 'Verstappen' },
        { score: 280, value: 'Norris' },
        { score: 300, value: 'Leclerc' },
        { score: 150, value: 'Hamilton' }
    ]);
    console.log('   Data added.');

    // 2. GETTING TOP-3 (ZRANGE)
    console.log('\n2. Getting TOP-3 Drivers:');
    const top3 = await client.zRangeWithScores(LEADERBOARD_KEY, 0, 2, { REV: true });
    
    top3.forEach((entry, index) => {
        console.log(`   #${index + 1} ${entry.value}: ${entry.score} pts`);
    });

    // 3. SITUATION CHANGE (ZINCRBY)
    console.log('\n3. Lando Norris wins! (+25 pts)');
    await client.zIncrBy(LEADERBOARD_KEY, 25, 'Norris');
    
    const norrisRank = await client.zRevRank(LEADERBOARD_KEY, 'Norris');
    const norrisScore = await client.zScore(LEADERBOARD_KEY, 'Norris');
    
    console.log(`   Norris is now at position #${(norrisRank ?? 0) + 1} with ${norrisScore} pts`);

    await client.del(LEADERBOARD_KEY);
    await disconnectRedis();
};

runRedisDemo().catch(console.error);