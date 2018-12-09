import { IRunner, IRunnerFactory } from "@prague/services-utils";
import { IKafkaResources } from "./resourcesFactory";
import { KafkaRunner } from "./runner";

export class KafkaRunnerFactory implements IRunnerFactory<IKafkaResources> {
    public async create(resources: IKafkaResources): Promise<IRunner> {
        return new KafkaRunner(
            resources.lambdaFactory,
            resources.consumer,
            resources.config);
    }
}
