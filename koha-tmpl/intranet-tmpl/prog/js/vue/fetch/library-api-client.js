import HttpClient from "./http-client";

export class LibraryAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/library_groups",
        });
    }

    get libraryGroups() {
        return {
            getAll: (query, params) =>
                this.getAll({
                    endpoint: "",
                    query,
                    params,
                }),
        };
    }
}

export default LibraryAPIClient;
