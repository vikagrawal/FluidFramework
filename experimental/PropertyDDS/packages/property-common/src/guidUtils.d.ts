/*!
 * Copyright (c) Microsoft Corporation and contributors. All rights reserved.
 * Licensed under the MIT License.
 */
export declare const GuidUtils: {
    uint32x4ToGUID: (in_guidArray: Uint32Array | Int32Array | number[], base64?: boolean) => string;
    guidToUint32x4: (in_guid: string, result?: Uint32Array) => Uint32Array;
    base64Tobase16: (in_guid: string) => string;
    base16ToBase64: (in_guid: string) => string;
    initializeGUIDGenerator: (...args: any[]) => void;
    generateGUID: (base64?: boolean) => string;
    isGUID: (in_guid: string) => boolean;
    combineGuids: (in_guid1: string, in_guid2: string, base64?: boolean) => string;
    hashCombine4xUint32: (in_array1: Uint32Array, in_array2: Uint32Array, io_result?: Uint32Array | undefined) => Uint32Array;
};
//# sourceMappingURL=guidUtils.d.ts.map