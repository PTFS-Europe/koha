$(document).ready(function () {
    let auto_ill_el = "#confirmautoill-form #autoillbackend";
    let found_backend = false;

    getBackendsAvailability(auto_backends, metadata);

    /**
     * Retrieves the backend availability for a given auto backend and metadata.
     *
     * @param {Object} auto_backend - The auto backend object.
     * @param {string} metadata - The metadata string.
     * @return {Promise} A Promise that resolves to the JSON response.
     */
    async function getBackendAvailability(auto_backend, metadata) {
        var response = await $.ajax({
            url: auto_backend.endpoint + metadata,
            type: "GET",
            dataType: "json",
            beforeSend: function () {
                _addBackendPlaceholderEl(auto_backend.name);
                _addVerifyingMessage(auto_backend.name);
            },
            success: function (data) {
                _addSuccessMessage(auto_backend.name);
                found_backend = true;
            },
            error: function (request, textstatus) {
                if (textstatus === "timeout") {
                    _addErrorMessage(
                        auto_backend.name,
                        __("Verification timed out.")
                    );
                } else {
                    _addErrorMessage(
                        auto_backend.name,
                        request.hasOwnProperty("responseJSON")
                            ? request.responseJSON.error
                            : JSON.stringify(request.responseJSON)
                    );
                }
            },
            timeout: 10000,
        });

        return response.json();
    }

    /**
     * Asynchronously checks the availability of multiple auto backends.
     *
     * @param {Array} auto_backends - An array of auto backends to check availability for.
     * @param {Object} metadata - Additional metadata for the availability check.
     * @return {void}
     */
    async function getBackendsAvailability(auto_backends, metadata) {
        for (const auto_backend of auto_backends) {
            if (found_backend) break;
            try {
                await getBackendAvailability(auto_backend, metadata);
            } catch {}
        }
        if (!found_backend) {
            _addBackendPlaceholderEl("Standard");
            _addSuccessMessage("Standard");
        }
    }

    function _addSuccessMessage(auto_backend_name) {
        $(auto_ill_el + " #" + auto_backend_name).append(
            '<span class="text-success">' +
                __(
                    "Your request will be placed as a <strong>%s</strong> request."
                ).format(auto_backend_name) +
                "</span>"
        );
        $('#confirmautoill-form .action input[name="backend"]').val(
            auto_backend_name
        );
    }

    function _addErrorMessage(auto_backend_name, message) {
        $(auto_ill_el + " #" + auto_backend_name).append(
            '<span class="text-danger">' +
                __("Unable to place request with <strong>%s</strong>:").format(
                    auto_backend_name
                ) +
                " " +
                message +
                "</span>"
        );
    }

    function _addVerifyingMessage(auto_backend_name) {
        $(auto_ill_el + " #" + auto_backend_name).append(
            __(
                "Verifying if your request can be placed with <strong>%s</strong>..."
            ).format(auto_backend_name) + "<br>"
        );
    }

    function _addBackendPlaceholderEl(auto_backend_name) {
        $(auto_ill_el).append('<div id="' + auto_backend_name + '">');
    }
});
