import HttpClient from "./http-client";

export class CircRuleAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/",
        });
    }

    get circRules() {
        return {
            getAll: (query, params, headers) =>
                this.getAll({
                    endpoint: "circulation_rules",
                    query,
                    params,
                    headers,
                }),
            update: rule =>
                this.put({
                    endpoint: "circulation_rules",
                    body: rule,
                }),
            count: (query = {}) =>
                this.count({
                    endpoint:
                        "circulation_rules?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default CircRuleAPIClient;
