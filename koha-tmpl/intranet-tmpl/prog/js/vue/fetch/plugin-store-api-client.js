import HttpClient from "./http-client";

export class PluginStoreAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "http://localhost:3000/",
        });
    }

    get plugins() {
        return {
            getAll: params =>
                this.getAll({
                    endpoint: "plugins",
                }),
        };
    }
}

export default PluginStoreAPIClient;
