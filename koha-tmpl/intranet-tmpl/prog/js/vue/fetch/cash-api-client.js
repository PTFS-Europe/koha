import HttpClient from "./http-client";

export class CashAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/",
        });
    }

    get cash_registers() {
        return {
            getAll: (query, params, headers) =>
                this.getAll({
                    endpoint: "cash_registers",
                    query,
                    params,
                    headers,
                }),
        };
    }
}

export default CashAPIClient;
