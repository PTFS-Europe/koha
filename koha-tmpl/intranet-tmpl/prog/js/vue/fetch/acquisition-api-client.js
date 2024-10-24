import HttpClient from "./http-client";

export class AcquisitionAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/acquisitions/",
        });
    }

    get vendors() {
        return {
            get: id =>
                this.get({
                    endpoint: "vendors/" + id,
                    headers: {
                        "x-koha-embed":
                            "baskets,aliases,subscriptions,interfaces,contacts,contracts",
                    },
                }),
            getAll: (query, params) =>
                this.getAll({
                    endpoint: "vendors",
                    query,
                    params,
                    headers: {
                        "x-koha-embed": "aliases",
                    },
                }),
            delete: id =>
                this.delete({
                    endpoint: "vendors/" + id,
                }),
            create: vendor =>
                this.post({
                    endpoint: "vendors",
                    body: vendor,
                }),
            update: (vendor, id) =>
                this.put({
                    endpoint: "vendors/" + id,
                    body: vendor,
                }),
            count: (query = {}) =>
                this.count({
                    endpoint:
                        "vendors?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default AcquisitionAPIClient;
