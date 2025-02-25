<script>
import ModuleDashboard from "../ModuleDashboard/ModuleDashboard.vue";
import ERMCounts from "../ModuleDashboard/Widgets/ERMCounts.vue";
import ERMLicensesNeedingAction from "../ModuleDashboard/Widgets/ERMLicensesNeedingAction.vue";
import ERMRunUsageReport from "../ModuleDashboard/Widgets/ERMRunUsageReport.vue";
import { markRaw } from "vue";

export default {
    extends: ModuleDashboard,
    setup() {
        return {
            ...ModuleDashboard.setup({
                availableWidgets: [
                    markRaw(ERMCounts),
                    markRaw(ERMLicensesNeedingAction),
                    markRaw(ERMRunUsageReport),
                ],
            }),
        };
    },
};
</script>
