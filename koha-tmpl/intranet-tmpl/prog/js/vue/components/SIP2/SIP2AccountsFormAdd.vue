<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="sip2_accounts_add">
        <h2 v-if="account.sip_account_id">
            {{ $__("Edit account #%s").format(account.sip_account_id) }}
        </h2>
        <h2 v-else>{{ $__("New account") }}</h2>
        <div>
            <form @submit="onSubmit($event)">
                <fieldset class="rows">
                    <ol>
                        <li
                            v-for="(attr, index) in resource_attrs.filter(
                                attr => attr.type !== 'relationship'
                            )"
                            v-bind:key="index"
                        >
                            <FormElement
                                :resource="account"
                                :attr="attr"
                                :index="index"
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="action">
                    <ButtonSubmit />
                    <router-link
                        :to="{ name: 'SIP2AccountsList' }"
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
import FormElement from "../FormElement.vue"
import ButtonSubmit from "../ButtonSubmit.vue"
import { setMessage, setError, setWarning } from "../../messages"
import { APIClient } from "../../fetch/api-client.js"
import SIP2AccountResource from "./SIP2AccountResource.vue"

export default {
    extends: SIP2AccountResource,
    setup() {
        return {
            ...SIP2AccountResource.setup(),
        }
    },
    data() {
        return {
            account: {
                ae_field_template: null,
                allow_additional_materials_checkout: false,
                allow_empty_passwords: false,
                av_field_template: null,
                blocked_item_types: null,
                checked_in_ok: false,
                cr_item_field: null,
                ct_always_send: false,
                cv_send_00_on_success: false,
                cv_triggers_alert: false,
                da_field_template: null,
                delimiter: "",
                encoding: "",
                error_detect: "enabled",
                format_due_date: false,
                hide_fields: null,
                holds_block_checkin: false,
                holds_get_captured: false,
                inhouse_item_types: null,
                inhouse_patron_categories: null,
                login_id: "",
                login_password: "",
                lost_status_for_missing: null,
                overdues_block_checkout: false,
                prevcheckout_block_checkout: false,
                register_id: null,
                seen_on_item_information: null,
                send_patron_home_library_in_af: null,
                show_checkin_message: false,
                show_outstanding_amount: false,
                sip_account_id: "",
                sip_institution_id: "",
                terminator: "",
            },
            initialized: false,
        }
    },
    beforeRouteEnter(to, from, next) {
        next(vm => {
            if (to.params.sip_account_id) {
                vm.getSIP2Account(to.params.sip_account_id)
            } else {
                vm.initialized = true
            }
        })
    },
    methods: {
        async getSIP2Account(sip_account_id) {
            const client = APIClient.sip2
            client.accounts.get(sip_account_id).then(
                data => {
                    this.account = data
                    this.initialized = true
                },
                error => {}
            )
        },
        onSubmit(e) {
            e.preventDefault()

            let account = JSON.parse(JSON.stringify(this.account)) // copy
            let sip_account_id = account.sip_account_id

            delete account.sip_account_id

            const client = APIClient.sip2
            if (sip_account_id) {
                client.accounts.update(account, sip_account_id).then(
                    success => {
                        setMessage(this.$__("Account updated"))
                        this.$router.push({ name: "SIP2AccountsList" })
                    },
                    error => {}
                )
            } else {
                client.accounts.create(account).then(
                    success => {
                        setMessage(this.$__("Account created"))
                        this.$router.push({ name: "SIP2AccountsList" })
                    },
                    error => {}
                )
            }
        },
    },
    components: {
        ButtonSubmit,
        FormElement,
    },
    name: "SIP2AccountsFormAdd",
}
</script>
