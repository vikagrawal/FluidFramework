import { createConsumer } from "@prague/services";
import { IConsumer } from "@prague/services-core";
import { IResources, IResourcesFactory } from "@prague/services-utils";
import * as moniker from "moniker";
import { Provider } from "nconf";
import { IPartitionLambdaFactory } from "./lambdas";

export interface IKafkaResources extends IResources {
    lambdaFactory: IPartitionLambdaFactory;

    consumer: IConsumer;

    config: Provider;
}

export class KafkaResources implements IKafkaResources {
    constructor(
        public lambdaFactory: IPartitionLambdaFactory,
        public consumer: IConsumer,
        public config: Provider) {
    }

    public async dispose(): Promise<void> {
        const consumerClosedP = this.consumer.close();
        await Promise.all([consumerClosedP]);
    }
}

export class KafkaResourcesFactory implements IResourcesFactory<KafkaResources> {
    constructor(private name, private lambdaModule) {
    }

    public async create(config: Provider): Promise<KafkaResources> {
        // tslint:disable-next-line:non-literal-require
        const plugin = require(this.lambdaModule);
        const lambdaFactory = await plugin.create(config) as IPartitionLambdaFactory;

        // Inbound Kafka configuration
        const kafkaEndpoint = config.get("kafka:lib:endpoint");
        const kafkaLibrary = config.get("kafka:lib:name");

        // Receive topic and group - for now we will assume an entry in config mapping
        // to the given name. Later though the lambda config will likely be split from the stream config
        const streamConfig = config.get(`lambdas:${this.name}`);
        const groupId = streamConfig.group;
        const receiveTopic = streamConfig.topic;

        const clientId = moniker.choose();
        const consumer = createConsumer(kafkaLibrary, kafkaEndpoint, clientId, groupId, receiveTopic, false);

        return new KafkaResources(
            lambdaFactory,
            consumer,
            config);
    }
}
