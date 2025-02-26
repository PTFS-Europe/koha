<template>
    <template v-if="display === 'picker'">
        <WidgetPickerWrapper
            :alreadyAdded="alreadyAdded"
            @added="addWidget"
            @removed="removeWidget"
            :name="name"
            :description="description"
        >
        </WidgetPickerWrapper>
    </template>
    <template v-else-if="display === 'dashboard'">
        <WidgetDashboardWrapper @removed="removeWidget" :name="name">
            <template #default>
                <div v-if="loading" class="text-center">
                    {{ $__("Loading...") }}
                </div>
                <p v-else class="text-left">
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
                                ><span v-else>{{
                                    definition.labelPlural
                                }}</span></a
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
        </WidgetDashboardWrapper>
    </template>
</template>
<script>
import { getCurrentInstance, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { APIClient } from "../../../fetch/api-client.js";
import WidgetDashboardWrapper from "../WidgetDashboardWrapper.vue";
import WidgetPickerWrapper from "../WidgetPickerWrapper.vue";
import BaseWidget from "../BaseWidget.vue";

export default {
    extends: BaseWidget,
    setup(props, { emit }) {
        const instance = getCurrentInstance();
        const loading = ref(true);
        const name = __("Counts");
        const description = __(
            "Shows the number of ERM related resources such as agreements, licenses, local packages, local titles, documents, etc"
        );

        const router = useRouter();
        const goToPage = page => {
            router.push({
                name: page,
            });
        };

        const getCounts = async () => {
            try {
                const response = await APIClient.erm.counts.get();

                Object.keys(response.counts).forEach(key => {
                    const item = instance.proxy.countDefinitions.find(
                        i => i.name === key
                    );
                    if (item) {
                        item.count = response.counts[key];
                    }
                });

                loading.value = false;
            } catch (error) {
                console.error(error);
            }
        };

        onMounted(() => {
            getCounts();
        });

        return {
            ...BaseWidget.setup(
                {
                    name,
                    description,
                    goToPage,
                    loading,
                },
                { emit }
            ),
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
    components: { WidgetDashboardWrapper, WidgetPickerWrapper },
    name: "ERMCounts",
};
</script>
