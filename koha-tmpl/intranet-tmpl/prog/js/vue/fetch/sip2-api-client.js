import HttpClient from "./http-client";

export class SIP2APIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/sip2",
        });
    }

    get institutions() {
        return {
            getAll: params =>
                this.getAll({
                    endpoint: "institutions",
                }),
        };
    }
}

export default SIP2APIClient;
