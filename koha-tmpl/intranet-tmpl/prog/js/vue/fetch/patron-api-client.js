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

    get userPermissions() {
        return {
            get: () =>
                this.get({
                    endpoint: "user_permissions",
                }),
        };
    }
}

export default PatronAPIClient;
