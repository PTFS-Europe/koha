import HttpClient from "./http-client";

export class BackgroundJobsAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/jobs",
        });
    }

    get jobs() {
        return {
            getAll: (query, params) =>
                this.getAll({
                    endpoint: "agreements",
                    query,
                    params,
                }),
        };
    }
}

export default BackgroundJobsAPIClient;
