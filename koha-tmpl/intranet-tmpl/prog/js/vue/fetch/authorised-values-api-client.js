import HttpClient from "./http-client";

export class AVAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "/api/v1/authorised_value_categories",
        });
    }

    get values() {
        return {
            get: category =>
                this.get({
                    endpoint: `/${category}/authorised_values`,
                }),
            getCategoriesWithValues: cat_array =>
                this.get({
                    endpoint:
                        '?q={"me.category_name":[' +
                        cat_array.join(", ") +
                        "]}",
                    headers: {
                        "x-koha-embed": "authorised_values",
                    },
                }).then(av_categories => {
                    av_categories.forEach(av_category => {
                        av_category.authorised_values =
                            av_category.authorised_values.map(av => ({
                                ...av,
                                description: av.description || av.value,
                            }));
                    });
                    return av_categories;
                }),
        };
    }
}

export default AVAPIClient;
