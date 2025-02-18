import HttpClient from "./http-client";

export class SIP2APIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/sip2/",
        });
    }

    get institutions() {
        return {
            get: id =>
                this.get({
                    endpoint: "institutions/" + id,
                }),
            getAll: params =>
                this.getAll({
                    endpoint: "institutions",
                }),
            delete: id =>
                this.delete({
                    endpoint: "institutions/" + id,
                }),
            create: institution =>
                this.post({
                    endpoint: "institutions",
                    body: institution,
                }),
            update: (institution, id) =>
                this.put({
                    endpoint: "institutions/" + id,
                    body: institution,
                }),
            count: (query = {}) =>
                this.count({
                    endpoint:
                        "institutions?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default SIP2APIClient;
