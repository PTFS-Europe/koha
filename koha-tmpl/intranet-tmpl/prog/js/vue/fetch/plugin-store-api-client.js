import HttpClient from "./http-client";

export class PluginStoreAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "",
        });
    }

    get plugins() {
        return {
            getStoreAll: koha_version_release =>
                this.getAll({
                    //FIXME: plugin store URL should come from koha-conf.xml (?)
                    endpoint:
                        "https://plugin-store.koha-ptfs.co.uk/api/plugins",
                    params: {
                        koha_version_release: koha_version_release
                            ? koha_version_release
                            : "",
                    },
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
