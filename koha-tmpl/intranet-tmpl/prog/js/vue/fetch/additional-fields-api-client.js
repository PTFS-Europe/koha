import HttpClient from "./http-client";

export class AdditionalFieldsAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/additional_fields",
        });
    }

    get additional_fields() {
        return {
            getAll: tablename =>
                this.get({
                    endpoint: "?tablename=" + tablename,
                }),
        };
    }
}

export default AdditionalFieldsAPIClient;
