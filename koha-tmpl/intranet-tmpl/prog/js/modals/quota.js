(() => {
    document
        .getElementById("quotaModal")
        ?.addEventListener("show.bs.modal", handleShowQuotaModal);
    document
        .getElementById("quotaForm")
        ?.addEventListener("submit", handleQuotaSubmit);
    document
        .getElementById("deleteQuotaModal")
        ?.addEventListener("show.bs.modal", handleShowDeleteModal);
    document
        .getElementById("deleteForm")
        ?.addEventListener("submit", handleDeleteSubmit);

    async function handleQuotaSubmit(e) {
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
        quota_table?.api().ajax.reload();

        $("#quotaModal").modal("hide");
        return;
    }

    function handleShowQuotaModal(e) {
        const button = e.relatedTarget;
        if (!button) {
            return;
        }

        const quotaModalLabel = document.getElementById("quotaLabel");
        const quotaModalSubmit = document.getElementById("quotaFormSubmit");

        const quotaIdInput = document.getElementById("quota_id");
        const quotaPatronInput = document.getElementById("patron_id");
        const quotaDescriptionInput = document.getElementById("quota_description");
        const quotaStartDateInput = document.getElementById("quota_from");
        const quotaEndDateInput = document.getElementById("quota_to");
        const quotaAllocationInput = document.getElementById("quota_allocation");

        const quota = button.dataset.quota;
        if (quota) {
            quotaIdInput.value = quota;
            quotaModalLabel.textContent = _("Edit quota");
            quotaModalSubmit.innerHTML = "<i class=\"fa fa-check\"></i> " + _("Update");
            quotaDescriptionInput.value = button.dataset.description;
            quotaStartDateInput._flatpickr.setDate(button.dataset.start_date, 1);
            quotaEndDateInput._flatpickr.setDate(button.dataset.end_date, 1);
            quotaAllocationInput.value = button.dataset.allocation;
        } else {
            quotaIdInput.value = null;
            quotaModalLabel.textContent = _("Add quota");
            quotaModalSubmit.innerHTML = "<i class=\"fa fa-fw fa-plus\"></i> " + _("Add");
            quotaDescriptionInput.value = null;
            quotaStartDateInput.value = null;
            quotaEndDateInput.value = null;
            quotaAllocationInput.value = null;
        }

        const patron = button.dataset.patron;
        quotaPatronInput.value = patron;

        return;
    }

    async function handleDeleteSubmit(e) {
        e.preventDefault();

        const target = e.target;
        if (!(target instanceof HTMLFormElement)) {
            return;
        }

        const formData = new FormData(target);
        const quotaId = formData.get("quota_id");
        const patronId = formData.get("patron_id");

        const quotaUrl = `/api/v1/patrons/${patronId}/quotas/${quotaId}`;
        let [error, response] = await catchError(
            fetch(quotaUrl, {
                method: "DELETE",
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

        quota_table?.api().ajax.reload();

        $("#deleteQuotaModal").modal("hide");
        return;
    }

    function handleShowDeleteModal(e) {
        const button = e.relatedTarget;
        if (!button) {
            return;
        }

        const quotaIdInput = document.getElementById("quota_id_delete");
        const quotaPatronInput = document.getElementById("patron_id_delete");

        const quota = button.dataset.quota;
        quotaIdInput.value = quota;
        const patron = button.dataset.patron;
        quotaPatronInput.value = patron;

        return;
    }

    function catchError(promise) {
        return promise.then(data => [undefined, data]).catch(error => [error]);
    }
})();
