import HttpClient from "./http-client";

export class RecordSourcesAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/record_sources",
        });
    }

    get record_source() {
        return {
            create: ({ row, headers = {} }) => {
                const requestHeaders = {
                    ...headers,
                    "Content-Type": "application/json",
                };
                return this.post({
                    endpoint: "",
                    headers: requestHeaders,
                    body: JSON.stringify(row),
                });
            },
            delete: ({ id, headers = {} }) => {
                return this.delete({
                    endpoint: "/" + id,
                    headers,
                });
            },
            update: ({ id, headers = {}, row }) => {
                const requestHeaders = {
                    ...headers,
                    "Content-Type": "application/json",
                };
                return this.put({
                    endpoint: "/" + id,
                    headers: requestHeaders,
                    body: JSON.stringify(row),
                });
            },
            get: ({ id, headers = {} }) => {
                return this.get({
                    endpoint: "/" + id,
                    headers,
                });
            },
            count: (query = {}) => {
                return this.count({
                    endpoint:
                        "?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                });
            },
        };
    }
}
