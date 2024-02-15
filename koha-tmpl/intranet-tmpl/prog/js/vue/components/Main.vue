<template>
    <ERM v-if="currentModule === 'erm'" />
    <Preservation v-if="currentModule === 'preservation'" />
    <Admin v-if="currentModule === 'admin'" />
</template>

<script>
import { inject } from "vue"
import ERM from "./ERM/ERM.vue"
import Preservation from "./Preservation/Preservation.vue"
import Admin from "./Admin/Admin.vue"

export default {
    setup() {
        const navigationStore = inject("navigationStore")
        return {
            currentModule: navigationStore.current[0].meta.self.module,
        }
    },
    components: {
        ERM,
        Preservation,
        Admin,
    },
}
</script>

<style></style>
