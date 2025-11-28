import { createClient } from 'redis';

const client = createClient({
    url: 'redis://localhost:6379'
});

client.on('error', (err) => console.log('Redis Client Error', err));

export const connectRedis = async () => {
    if (!client.isOpen) {
        await client.connect();
        console.log('Connected to Redis');
    }
    return client;
};

export const disconnectRedis = async () => {
    if (client.isOpen) {
        await client.disconnect();
        console.log('Disconnected from Redis');
    }
};