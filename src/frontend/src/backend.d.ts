import type { Principal } from "@icp-sdk/core/principal";
export interface Some<T> {
    __kind__: "Some";
    value: T;
}
export interface None {
    __kind__: "None";
}
export type Option<T> = Some<T> | None;
export interface backendInterface {
    evaluate(input: string): Promise<{
        __kind__: "ok";
        ok: {
            value: string;
            typeStr: string;
        };
    } | {
        __kind__: "err";
        err: string;
    }>;
    reset(): Promise<void>;
    getEnv(): Promise<Array<{
        name: string;
        typeStr: string;
        valueStr: string;
    }>>;
}
