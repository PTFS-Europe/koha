<template>
    <WidgetWrapper v-bind="widgetWrapperProps">
        <template #default>
            <p class="text-left">
                {{ $__("There are") }}
                <template
                    v-for="(definition, index) in countDefinitions"
                    :key="index"
                >
                    <strong>
                        <a
                            v-if="definition.page"
                            href="#"
                            @click.prevent="goToPage(definition.page)"
                            >{{ definition.count }}
                            <span v-if="definition.count == 1">{{
                                definition.labelSingular
                            }}</span
                            ><span v-else>{{ definition.labelPlural }}</span></a
                        >
                        <span v-else
                            >{{ definition.count }}
                            <span v-if="definition.count == 1">{{
                                definition.labelSingular
                            }}</span
                            ><span v-else>{{
                                definition.labelPlural
                            }}</span></span
                        >
                    </strong>
                    <template v-if="index < countDefinitions.length - 1"
                        >,&nbsp;</template
                    >
                    <template v-else>.</template>
                </template>
            </p>
        </template>
    </WidgetWrapper>
</template>
<script>
import { APIClient } from "../../../fetch/api-client.js";
import WidgetWrapper from "../WidgetWrapper.vue";
import BaseWidget from "../BaseWidget.vue";

export default {
    extends: BaseWidget,
    setup(props) {
        return {
            ...BaseWidget.setup({
                id: "ERMCounts",
                name: __("Counts"),
                description: __(
                    "Shows the number of ERM related resources such as agreements, licenses, local packages, local titles, documents, etc."
                ),
            }),
        };
    },
    data() {
        return {
            countDefinitions: [
                {
                    page: "AgreementsList",
                    name: "agreements_count",
                    labelSingular: this.$__("agreement"),
                    labelPlural: this.$__("agreements"),
                    count: 0,
                },
                {
                    page: "LicensesList",
                    name: "licenses_count",
                    labelSingular: this.$__("license"),
                    labelPlural: this.$__("licenses"),
                    count: 0,
                },
                {
                    name: "documents_count",
                    labelSingular: this.$__("document"),
                    labelPlural: this.$__("documents"),
                    count: 0,
                },
                {
                    page: "EHoldingsLocalPackagesList",
                    name: "eholdings_packages_count",
                    labelSingular: this.$__("local package"),
                    labelPlural: this.$__("local packages"),
                    count: 0,
                },
                {
                    page: "EHoldingsLocalTitlesList",
                    name: "eholdings_titles_count",
                    labelSingular: this.$__("local title"),
                    labelPlural: this.$__("local titles"),
                    count: 0,
                },
                {
                    page: "UsageStatisticsDataProvidersList",
                    name: "usage_data_providers_count",
                    labelSingular: this.$__("usage data provider"),
                    labelPlural: this.$__("usage data providers"),
                    count: 0,
                },
            ],
        };
    },
    methods: {
        async getCounts() {
            try {
                const response = await APIClient.erm.counts.get();

                Object.keys(response.counts).forEach(key => {
                    const item = this.countDefinitions.find(
                        i => i.name === key
                    );
                    if (item) {
                        item.count = response.counts[key];
                    }
                });
                this.loading = false;
            } catch (error) {
                console.error(error);
            }
        },
        onDashboardMounted() {
            this.getCounts();
        },
        goToPage(page) {
            this.$router.push({
                name: page,
            });
        },
    },
    components: { BaseWidget, WidgetWrapper },
    name: "ERMCounts",
};
</script>
