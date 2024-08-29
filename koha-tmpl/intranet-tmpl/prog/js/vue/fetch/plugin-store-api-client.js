import HttpClient from "./http-client";

export class PluginStoreAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "",
        });
    }

    get plugins() {
        return {
            getAll: params =>
                this.getAll({
                    endpoint: "http://localhost:3000/api/plugins",
                }),
            create: plugin =>
                this.post({
                    endpoint: "/api/v1/plugins",
                    body: plugin,
                }),
        };
    }
}

export default PluginStoreAPIClient;
