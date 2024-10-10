<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="sip2_institutions_add">
        <h2 v-if="institution.sip_institution_id">
            {{
                $__("Edit institution #%s").format(
                    institution.sip_institution_id
                )
            }}
        </h2>
        <h2 v-else>{{ $__("New institution") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <label for="institution_name" class="required"
                                >{{ $__("Name") }}:</label
                            >
                            <input
                                id="institution_name"
                                v-model="institution.name"
                                :placeholder="$__('Institution name')"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label
                                for="institution_implementation"
                                class="required"
                                >{{ $__("Implementation") }}:</label
                            >
                            <input
                                id="institution_implementation"
                                v-model="institution.implementation"
                                :placeholder="$__('Implementation')"
                                required
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="rows" id="policy">
                    <legend>{{ $__("Policy") }}</legend>
                    <ol>
                        <li>
                            <label for="institution_checkin"
                                >{{ $__("Checkin") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="institution_checkin"
                                v-model="institution.checkin"
                            />
                        </li>
                        <li>
                            <label for="institution_checkout"
                                >{{ $__("Checkout") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="institution_checkout"
                                v-model="institution.checkout"
                            />
                        </li>
                        <li>
                            <label for="institution_renewal"
                                >{{ $__("Renewal") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="institution_renewal"
                                v-model="institution.renewal"
                            />
                        </li>
                        <li>
                            <label for="institution_retries" class="required"
                                >{{ $__("Retries") }}:</label
                            >
                            <input
                                id="institution_retries"
                                v-model="institution.retries"
                                :placeholder="$__('Retries')"
                                required
                            />
                        </li>
                        <li>
                            <label for="institution_status_update"
                                >{{ $__("Status update") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="institution_status_update"
                                v-model="institution.status_update"
                            />
                        </li>
                        <li>
                            <label for="institution_timeout" class="required"
                                >{{ $__("Timeout") }}:</label
                            >
                            <input
                                id="institution_timeout"
                                v-model="institution.timeout"
                                :placeholder="$__('Timeout')"
                                required
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <ButtonSubmit />
                    <router-link
                        :to="{ name: 'SIP2InstitutionsList' }"
                        role="button"
                        class="cancel"
                        >{{ $__("Cancel") }}</router-link
                    >
                </fieldset>
            </form>
        </div>
    </div>
</template>

<script>
import ButtonSubmit from "../ButtonSubmit.vue"
import { setMessage, setError, setWarning } from "../../messages"
import { APIClient } from "../../fetch/api-client.js"

export default {
    data() {
        return {
            institution: {
                sip_institution_id: null,
                name: "",
                implementation: "",
                checkin: false,
                checkout: false,
                renewal: false,
                retries: 5,
                status_update: false,
                timeout: 100,
            },
            initialized: false,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            if (to.params.sip_institution_id) {
                vm.getSIP2Institution(to.params.sip_institution_id)
            } else {
                vm.initialized = true
            }
        })
    },
    methods: {
        async getSIP2Institution(sip_institution_id) {
            const client = APIClient.sip2
            client.institutions.get(sip_institution_id).then(
                data => {
                    this.institution = data
                    this.initialized = true
                },
                error => {}
            )
        },
        onSubmit(e) {
            e.preventDefault()

            let institution = JSON.parse(JSON.stringify(this.institution)) // copy
            let sip_institution_id = institution.sip_institution_id

            delete institution.sip_institution_id

            const client = APIClient.sip2
            if (sip_institution_id) {
                client.institutions
                    .update(institution, sip_institution_id)
                    .then(
                        success => {
                            setMessage(this.$__("Institution updated"))
                            this.$router.push({ name: "SIP2InstitutionsList" })
                        },
                        error => {}
                    )
            } else {
                client.institutions.create(institution).then(
                    success => {
                        setMessage(this.$__("Institution created"))
                        this.$router.push({ name: "SIP2InstitutionsList" })
                    },
                    error => {}
                )
            }
        },
    },
    components: {
        ButtonSubmit,
    },
    name: "SIP2InstitutionsFormAdd",
}
</script>
