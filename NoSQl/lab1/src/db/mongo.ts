import mongoose from 'mongoose';

const MONGO_URI = 'mongodb://localhost:27017/f1_telemetry'; 

export const connectMongo = async () => {
    try {
        await mongoose.connect(MONGO_URI);
        console.log('Connected to MongoDB');
    } catch (error) {
        console.error('MongoDB connection error:', error);
        process.exit(1);
    }
};

export const disconnectMongo = async () => {
    await mongoose.disconnect();
    console.log('Disconnected from MongoDB');
};