import HttpClient from "./http-client";

export class LibraryAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/",
        });
    }

    get libraries() {
        return {
            getAll: (query, params, headers) =>
                this.getAll({
                    endpoint: "libraries",
                    query,
                    params,
                    headers,
                }),
        };
    }
}

export default LibraryAPIClient;
