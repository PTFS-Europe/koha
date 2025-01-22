import { setError, submitting, submitted } from "../messages";

class HttpClient {
    constructor(options = {}) {
        this._baseURL = options.baseURL || "";
        this._headers = options.headers || {
            "Content-Type": "application/json;charset=utf-8",
        };
    }

    async _fetchJSON(
        endpoint,
        headers = {},
        options = {},
        return_response = false,
        mark_submitting = false
    ) {
        let res, error;
        if (mark_submitting) submitting();
        await fetch(this._baseURL + endpoint, {
            ...options,
            headers: { ...this._headers, ...headers },
        })
            .then(response => {
                if (!response.ok) {
                    return response.text().then(text => {
                        let message;
                        let errorResponse = {};
                        if (text) {
                            let json = JSON.parse(text);
                            message =
                                json.error ||
                                json.errors.map(e => e.message).join("\n") ||
                                json;
                            errorResponse = {
                                message,
                                ...json,
                            };
                        } else {
                            message = response.statusText;
                        }
                        throwDetailedError(message, errorResponse);
                    });
                }
                return return_response ? response : response.json();
            })
            .then(result => {
                res = result;
            })
            .catch(err => {
                if (err.dialog_confirm) {
                    error = err.message;
                    if (mark_submitting) submitted();
                    throwDetailedError(err.message, err);
                } else {
                    error = err.message;
                    setError(err.message);
                }
            })
            .then(() => {
                if (mark_submitting) submitted();
            });

        if (error) throw Error(error);

        return res;
    }

    get(params = {}) {
        return this._fetchJSON(params.endpoint, params.headers, {
            ...params.options,
            method: "GET",
        });
    }

    getAll(params = {}) {
        let url =
            params.endpoint +
            "?" +
            new URLSearchParams({
                _per_page: -1,
                ...(params.params && params.params),
                ...(params.query && { q: JSON.stringify(params.query) }),
            });
        return this._fetchJSON(url, params.headers, {
            ...params.options,
            method: "GET",
        });
    }

    post(params = {}) {
        const body = params.body
            ? typeof params.body === "string"
                ? params.body
                : JSON.stringify(params.body)
            : undefined;
        return this._fetchJSON(
            params.endpoint,
            params.headers,
            {
                ...params.options,
                body,
                method: "POST",
            },
            false,
            true
        );
    }

    put(params = {}) {
        const body = params.body
            ? typeof params.body === "string"
                ? params.body
                : JSON.stringify(params.body)
            : undefined;
        return this._fetchJSON(
            params.endpoint,
            params.headers,
            {
                ...params.options,
                body,
                method: "PUT",
            },
            false,
            true
        );
    }

    delete(params = {}) {
        return this._fetchJSON(
            params.endpoint,
            params.headers,
            {
                parseResponse: false,
                ...params.options,
                method: "DELETE",
            },
            true,
            true
        );
    }

    count(params = {}) {
        let res;
        return this._fetchJSON(params.endpoint, params.headers, {}, 1).then(
            response => {
                if (response) {
                    return response.headers.get("X-Total-Count");
                }
            },
            error => {}
        );
    }

    patch(params = {}) {
        const body = params.body
            ? typeof params.body === "string"
                ? params.body
                : JSON.stringify(params.body)
            : undefined;
        return this._fetchJSON(params.endpoint, params.headers, {
            ...params.options,
            body,
            method: "PATCH",
        });
    }
}

export default HttpClient;

const throwDetailedError = (message, errorData) => {
    let errorDetails = new Error(message);
    errorDetails = {
        ...errorDetails,
        ...errorData,
    };
    throw errorDetails;
};
