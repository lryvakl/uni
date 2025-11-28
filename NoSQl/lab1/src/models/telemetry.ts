import mongoose, { Schema, Document } from 'mongoose';

export interface ILap {
    lap_number: number;
    sector_1: number;
    sector_2: number;
    sector_3: number;
    tyre_compound: string;
}

export interface ITelemetry extends Document {
    session_id: number; 
    driver_id: number; 
    car_setup: any;   
    laps: ILap[];
}

const TelemetrySchema: Schema = new Schema({
    session_id: { type: Number, required: true, index: true },
    driver_id: { type: Number, required: true },
    car_setup: { type: Schema.Types.Mixed },
    laps: [{
        lap_number: Number,
        sector_1: Number,
        sector_2: Number,
        sector_3: Number,
        tyre_compound: String
    }]
});

TelemetrySchema.index({ session_id: 1, driver_id: 1 });

export const TelemetryModel = mongoose.model<ITelemetry>('Telemetry', TelemetrySchema);