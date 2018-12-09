import * as core from "@prague/services-core";
import { Collection, MongoClient, MongoClientOptions } from "mongodb";

const MaxFetchSize = 2000;

export class MongoCollection<T> implements core.ICollection<T> {
    constructor(private collection: Collection<T>) {
    }

    public find(query: object, sort: any, limit = MaxFetchSize): Promise<T[]> {
        return this.collection
            .find(query)
            .sort(sort)
            .limit(limit)
            .toArray();
    }

    public findOne(query: object): Promise<T> {
        return this.collection.findOne(query);
    }

    public findAll(): Promise<T[]> {
        return this.collection.find({}).toArray();
    }

    public async update(filter: object, set: any, addToSet: any): Promise<void> {
        return this.updateCore(filter, set, addToSet, false);
    }

    public async upsert(filter: object, set: any, addToSet: any): Promise<void> {
        return this.updateCore(filter, set, addToSet, true);
    }

    public async insertOne(value: T): Promise<any> {
        const result = await this.collection.insertOne(value);
        return result.insertedId;
    }

    public async insertMany(values: T[], ordered: boolean): Promise<void> {
        await this.collection.insertMany(values, { ordered: false });
    }

    public async createIndex(index: any, unique: boolean): Promise<void> {
        await this.collection.createIndex(index, { unique });
    }

    public async findOrCreate(query: any, value: T): Promise<{ value: T, existing: boolean }> {
        const result = await this.collection.findOneAndUpdate(
            query,
            {
                $setOnInsert: value,
            },
            {
                returnOriginal: true,
                upsert: true,
            });

        if (result.value) {
            return { value: result.value, existing: true };
        } else {
            return { value, existing: false };
        }
    }

    private async updateCore(filter: any, set: any, addToSet: any, upsert: boolean): Promise<void> {
        const update: any = {};
        if (set) {
            update.$set = set;
        }

        if (addToSet) {
            update.$addToSet = addToSet;
        }

        const options = { upsert };

        await this.collection.updateOne(filter, update, options);
    }
}

export class MongoDb implements core.IDb {
    constructor(private client: MongoClient) {
    }

    public close(): Promise<void> {
        return this.client.close();
    }

    public on(event: string, listener: (...args: any[]) => void) {
        this.client.on(event, listener);
    }

    public collection<T>(name: string): core.ICollection<T> {
        const collection = this.client.db().collection<T>(name);
        return new MongoCollection<T>(collection);
    }
}

export class MongoDbFactory implements core.IDbFactory {
    constructor(private endpoint: string) {
    }

    public async connect(): Promise<core.IDb> {
        // Need to cast to any before MongoClientOptions due to missing properties in d.ts
        const options: MongoClientOptions = {
            autoReconnect: false,
            bufferMaxEntries: 0,
        } as any;

        const connection = await MongoClient.connect(this.endpoint, options);

        return new MongoDb(connection);
    }
}
