<template>
    <h1 id="acq2_homepage">Homepage</h1>
</template>

<script>
import { inject } from "vue"
import { storeToRefs } from "pinia"
import { setWarning } from "../../../messages"

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore")
        const { navigationBlocked } = storeToRefs(acquisitionsStore)

        return {
            navigationBlocked,
        }
    },
    beforeCreate() {
        if (this.navigationBlocked) {
            setWarning(
                "You did not have the required permissions to access that page. Please contact your system administrator."
            )
            this.navigationBlocked = false
        }
    },
}
</script>

<style></style>
