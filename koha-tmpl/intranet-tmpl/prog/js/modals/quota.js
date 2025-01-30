(() => {
    document
        .getElementById("quotaModal")
        ?.addEventListener("show.bs.modal", handleShowBsModal);
    document
        .getElementById("quotaForm")
        ?.addEventListener("submit", handleSubmit);

    async function handleSubmit(e) {
        e.preventDefault();

        const target = e.target;
        if (!(target instanceof HTMLFormElement)) {
            return;
        }

        const formData = new FormData(target);
        const quotaId = formData.get("quota_id");
        const patronId = formData.get("patron_id");
        const description = formData.get("description");
        const startDate = formData.get("start_date");
        const endDate = formData.get("end_date");
        const allocation = formData.get("allocation");

        const quotaUrl = quotaId ? `/api/v1/patrons/${patronId}/quotas/${quotaId}` : `/api/v1/patrons/${patronId}/quotas`;
        let [error, response] = await catchError(
            fetch(quotaUrl, {
                method: quotaId ? "PUT" : "POST",
                body: JSON.stringify({
                    patron_id: patronId,
                    description: description,
                    start_date: startDate,
                    end_date: endDate,
                    allocation: allocation
                }),
                headers: {
                    "Content-Type": "application/json",
                },
            })
        );
        if (error || !response.ok) {
            const alertContainer = document.getElementById(
                "quota_result"
            );
            alertContainer.outerHTML = `
                <div id="quota_result" class="alert alert-danger">
                    ${__("Failure")}
                </div>
            `;

            return;
        }

        quota_success = true;
        quotas_table?.api().ajax.reload();

        $("#quotaModal").modal("hide");
    }

    function handleShowBsModal(e) {
        const button = e.relatedTarget;
        if (!button) {
            return;
        }

        const quotaModalLabel = document.getElementById("quotaLabel");
        const quotaModalSubmit = document.getElementById("quotaFormSubmit");

        const quota = button.dataset.quota;
        const quotaIdInput = document.getElementById("quota_id");
        if (quota) {
            quotaIdInput.value = quota;
            quotaModalLabel.textContent = _("Edit quote");
            quotaModalSubmit.innerHTML = "<i class=\"fa fa-check\"></i> " + _("Update");
        } else {
            quotaIdInput.value = null;
            quotaModalLabel.textContent = _("Add quota");
            quotaModalSubmit.innerHTML = "<i class=\"fa fa-fw fa-plus\"></i> " + _("Add");
        }

        const patron = button.dataset.borrowernumber;
        const quotaPatronInput = document.getElementById("quota_patron_id");
        quotaPatronInput.value = patron;

        return;
    }

    function catchError(promise) {
        return promise.then(data => [undefined, data]).catch(error => [error]);
    }
})();
