/*!
 * Copyright (c) Microsoft Corporation and contributors. All rights reserved.
 * Licensed under the MIT License.
 */
// In this case we want @types/express-serve-static-core, not express-serve-static-core, and so disable the lint rule
// eslint-disable-next-line import/no-unresolved
import { Params } from "express-serve-static-core";
import { getParam } from "@fluidframework/server-services-utils";
import { ITokenClaims } from "@fluidframework/protocol-definitions";
import { NetworkError } from "@fluidframework/server-services-client";
import { Lumberjack } from "@fluidframework/server-services-telemetry";
import * as jwt from "jsonwebtoken";
import winston from "winston";
import safeStringify from "json-stringify-safe";

export function normalizePort(val) {
    const normalizedPort = parseInt(val, 10);

    if (isNaN(normalizedPort)) {
        // named pipe
        // eslint-disable-next-line @typescript-eslint/no-unsafe-return
        return val;
    }

    if (normalizedPort >= 0) {
        // port number
        return normalizedPort;
    }

    return false;
}

export function getTokenLifetimeInSec(token: string): number {
    const claims = jwt.decode(token) as ITokenClaims;
    if (claims && claims.exp) {
        return (claims.exp - Math.round((new Date().getTime()) / 1000));
    }
    return undefined;
}

export function getTenantIdFromRequest(params: Params) {
    const tenantId = getParam(params, "tenantId");
    if (tenantId !== undefined) {
        return tenantId;
    }
    const id = getParam(params, "id");
    if (id !== undefined) {
        return id;
    }

    return "-";
}

export function getDocumentIdFromRequest(tenantId: string, authorization: string) {
    try {
        const token = parseToken(tenantId, authorization);
        const decoded = jwt.decode(token) as ITokenClaims;
        return decoded.documentId;
    } catch (err) {
        return "-";
    }
}

export function parseToken(tenantId: string, authorization: string): string {
    let token: string;
    if (authorization) {
        // eslint-disable-next-line @typescript-eslint/prefer-regexp-exec
        const base64TokenMatch = authorization.match(/Basic (.+)/);
        if (!base64TokenMatch) {
            throw new NetworkError(403, "Malformed authorization token");
        }
        const encoded = Buffer.from(base64TokenMatch[1], "base64").toString();

        // eslint-disable-next-line @typescript-eslint/prefer-regexp-exec
        const tokenMatch = encoded.match(/(.+):(.+)/);
        if (!tokenMatch || tenantId !== tokenMatch[1]) {
            throw new NetworkError(403, "Malformed authorization token");
        }

        token = tokenMatch[2];
    }

    return token;
}

/**
 * Pass into `.catch()` block of a RestWrapper call to output a more standardized network error.
 * @param url request url to be output in error log
 * @param method request method (e.g. "GET", "POST") to be output in error log
 * @param networkErrorOverride NetworkError to throw, regardless of error received from request
 */
export function getRequestErrorTranslator(
    url: string,
    method: string,
    lumberProperties?: Map<string, any> | Record<string, any>): (error: any) => never {
    const standardLogErrorMessage = `[${method}] Request to [${url}] failed`;
    const requestErrorTranslator = (error: any): never => {
        // BasicRestWrapper only throws `AxiosError.response.status` when available.
        // Only bubble the error code, but log additional details for debugging purposes
        if (typeof error === "number" || !Number.isNaN(Number.parseInt(error, 10)))  {
            const errorCode = typeof error === "number" ? error : Number.parseInt(error, 10);
            winston.error(`${standardLogErrorMessage}: ${errorCode}`);
            Lumberjack.error(`${standardLogErrorMessage}: ${errorCode}`, lumberProperties);
            throw new NetworkError(
                errorCode,
                "Internal Service Request Failed",
            );
        }
        // Treat anything else as an internal error, but log for debugging purposes
        winston.error(`${standardLogErrorMessage}: ${safeStringify(error)}`);
        Lumberjack.error(standardLogErrorMessage, lumberProperties, error);
        throw new NetworkError(500, "Internal Server Error");
    };
    return requestErrorTranslator;
}
