import HttpClient from "./http-client";

export class PluginStoreAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/",
        });
    }

    get plugins() {
        return {
            getAll: params =>
                this.getAll({
                    endpoint: "plugins",
                }),
            create: plugin =>
                this.post({
                    endpoint: "plugins",
                    body: plugin,
                }),
        };
    }
}

export default PluginStoreAPIClient;
