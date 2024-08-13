import HttpClient from "./http-client";

export class PatronAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/",
        });
    }

    get patrons() {
        return {
            get: id =>
                this.get({
                    endpoint: "patrons/" + id,
                }),
        };
    }
    get patronCategories() {
        return {
            getAll: (query, params, headers) =>
                this.getAll({
                    endpoint: "patron_categories",
                    query,
                    params,
                    headers,
                }),
        };
    }
}

export default PatronAPIClient;
