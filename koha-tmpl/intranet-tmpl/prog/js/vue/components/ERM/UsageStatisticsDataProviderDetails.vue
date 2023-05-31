<template>
    <legend>{{ $__("Data provider") }}</legend>
    <fieldset class="rows">
        <ol>
            <li>
                <label>{{ $__("Data provider name") }}:</label>
                <span>
                    {{ usage_data_provider.name }}
                </span>
            </li>
            <li>
                <label>{{ $__("Description") }}:</label>
                <span>
                    {{ usage_data_provider.description }}
                </span>
            </li>
            <li>
                <label>{{ $__("Status") }}:</label>
                <span>
                    {{ usage_data_provider.active ? "Active" : "Inactive" }}
                </span>
            </li>
            <li>
                <label>{{ $__("Service Type") }}:</label>
                <span>
                    {{ usage_data_provider.service_type }}
                </span>
            </li>
            <li>
                <label>{{ $__("Harvest Start") }}:</label>
                <span>
                    {{ usage_data_provider.begin_date }}
                </span>
            </li>
            <li>
                <label>{{ $__("Harvest End") }}:</label>
                <span>
                    {{ usage_data_provider.end_date }}
                </span>
            </li>
            <li>
                <label>{{ $__("Report types") }}:</label>
                <span>
                    {{ usage_data_provider.report_types }}
                </span>
            </li>
        </ol>
    </fieldset>
    <legend>{{ $__("Sushi credentials") }}</legend>
    <fieldset class="rows">
        <ol>
            <li>
                <label>{{ $__("Service URL") }}:</label>
                <span>
                    {{ usage_data_provider.service_url }}
                </span>
            </li>
            <li>
                <label>{{ $__("Report Release") }}:</label>
                <span>
                    {{ usage_data_provider.report_release }}
                </span>
            </li>
            <li>
                <label>{{ $__("Customer Id") }}:</label>
                <span>
                    {{ usage_data_provider.customer_id }}
                </span>
            </li>
            <li>
                <label>{{ $__("Requestor Id") }}:</label>
                <span>
                    {{ usage_data_provider.requestor_id }}
                </span>
            </li>
            <li>
                <label>{{ $__("API Key") }}:</label>
                <span>
                    {{ usage_data_provider.api_key }}
                </span>
            </li>
            <li>
                <label>{{ $__("Requestor Name") }}:</label>
                <span>
                    {{ usage_data_provider.requestor_name }}
                </span>
            </li>
            <li>
                <label>{{ $__("Requestor Email") }}:</label>
                <span>
                    {{ usage_data_provider.requestor_email }}
                </span>
            </li>
        </ol>
    </fieldset>
</template>

<script>
export default {
    props: ["usage_data_provider"],
    name: "UsageStatisticsDataProviderDetails",
}
</script>
