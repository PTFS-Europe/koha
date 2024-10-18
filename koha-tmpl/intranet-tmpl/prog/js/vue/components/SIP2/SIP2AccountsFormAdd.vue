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
                        <li>
                            <label for="account_login_id" class="required"
                                >{{ $__("Login") }}:</label
                            >
                            <input
                                id="account_login_id"
                                v-model="account.login_id"
                                :placeholder="$__('Account login id')"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="account_login_password" class="required"
                                >{{ $__("Password") }}:</label
                            >
                            <input
                                id="account_login_password"
                                v-model="account.login_password"
                                :placeholder="$__('Account login password')"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="account_institution_id" class="required"
                                >{{ $__("TODO: institution picker") }}:</label
                            >
                            <input
                                id="account_institution_id"
                                v-model="account.sip_institution_id"
                                :placeholder="$__('TODO: institution picker')"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label
                                for="account_allow_additional_materials_checkout"
                                >{{
                                    $__("Allow additional materials checkout")
                                }}:</label
                            >
                            <input
                                type="checkbox"
                                id="account_allow_additional_materials_checkout"
                                v-model="
                                    account.allow_additional_materials_checkout
                                "
                            />
                        </li>
                        <li>
                            <label for="account_allow_empty_passwords"
                                >{{ $__("Allow empty passwords") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="account_allow_empty_passwords"
                                v-model="account.allow_empty_passwords"
                            />
                        </li>
                        <li>
                            <label for="account_blocked_items_types"
                                >{{ $__("Blocked item types") }}:</label
                            >
                            <input
                                id="account_blocked_items_types"
                                v-model="account.blocked_item_types"
                                placeholder="VM|MU"
                            />
                        </li>
                        <li>
                            <label for="account_checked_in_ok"
                                >{{ $__("Checked in OK") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="account_checked_in_ok"
                                v-model="account.checked_in_ok"
                            />
                        </li>
                        <li>
                            <label for="account_cr_item_field"
                                >{{ $__("CR item field") }}:</label
                            >
                            <input
                                id="account_cr_item_field"
                                v-model="account.cr_item_field"
                                placeholder="shelving_location"
                            />
                        </li>
                        <li>
                            <label for="account_ct_always_send"
                                >{{ $__("CT always send") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="account_ct_always_send"
                                v-model="account.ct_always_send"
                            />
                        </li>
                        <li>
                            <label for="account_cv_send_00_on_success"
                                >{{ $__("CT always send") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="account_cv_send_00_on_success"
                                v-model="account.cv_send_00_on_success"
                            />
                        </li>
                        <li>
                            <label for="account_cv_triggers_alert"
                                >{{ $__("CV triggers alert") }}:</label
                            >
                            <input
                                type="checkbox"
                                id="account_cv_triggers_alert"
                                v-model="account.cv_triggers_alert"
                            />
                        </li>
                        <li>
                            <label for="account_delimiter" class="required"
                                >{{ $__("Delimiter") }}:</label
                            >
                            <input
                                id="account_delimiter"
                                v-model="account.delimiter"
                                placeholder="|"
                                required
                            />
                            <span class="required">{{ $__("Required") }}</span>
                        </li>
                        <li>
                            <label for="account_encoding"
                                >{{ $__("Encoding") }}:</label
                            >
                            <input
                                id="account_encoding"
                                v-model="account.encoding"
                                placeholder="utf8"
                            />
                        </li>
                    </ol>
                </fieldset>
                <fieldset class="rows" id="field_templates">
                    <legend>{{ $__("Field templates") }}</legend>
                    <ol>
                        <li>
                            <label for="account_ae_field_template"
                                >{{ $__("AV field template") }}:</label
                            >
                            <textarea
                                id="account_ae_field_template"
                                v-model="account.av_field_template"
                                placeholder="[% patron.surname %][% IF patron.firstname %], [% patron.firstname %][% END %]"
                                rows="3"
                                cols="50"
                            />
                        </li>
                        <li>
                            <label for="account_av_field_template"
                                >{{ $__("AE field template") }}:</label
                            >
                            <textarea
                                id="account_av_field_template"
                                v-model="account.ae_field_template"
                                placeholder="[% accountline.description %] [% accountline.amountoutstanding | format('%.2f') %]"
                                rows="3"
                                cols="50"
                            />
                        </li>
                        <li>
                            <label for="account_da_field_template"
                                >{{ $__("DA field template") }}:</label
                            >
                            <textarea
                                id="account_da_field_template"
                                v-model="account.da_field_template"
                                placeholder="[% patron.surname %][% IF patron.firstname %], [% patron.firstname %][% END %]"
                                rows="3"
                                cols="50"
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
import ButtonSubmit from "../ButtonSubmit.vue"
import { setMessage, setError, setWarning } from "../../messages"
import { APIClient } from "../../fetch/api-client.js"

export default {
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
    },
    name: "SIP2AccountsFormAdd",
}
</script>
