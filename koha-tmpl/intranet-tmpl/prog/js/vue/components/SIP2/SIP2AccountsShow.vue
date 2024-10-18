<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <div v-else id="accounts_show">
        <Toolbar>
            <ToolbarButton
                action="edit"
                @go-to-edit-resource="goToResourceEdit"
            />
            <ToolbarButton
                action="delete"
                @delete-resource="doResourceDelete"
            />
        </Toolbar>

        <h2>
            {{ $__("Account #%s").format(account.sip_account_id) }}
        </h2>
        <div>
            <fieldset class="rows">
                <ol>
                    <li>
                        <label>{{ $__("Account name") }}:</label>
                        <span>
                            {{ account.name }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Implementation") }}:</label>
                        <span>
                            {{ account.implementation }}
                        </span>
                    </li>
                </ol>
            </fieldset>
            <h3>{{ $__("Policy") }}</h3>
            <fieldset class="rows">
                <ol>
                    <li>
                        <label>{{ $__("Checkin") }}:</label>
                        <span v-if="account.checkin">{{ $__("Yes") }}</span>
                        <span v-else>{{ $__("No") }}</span>
                    </li>
                    <li>
                        <label>{{ $__("Checkout") }}:</label>
                        <span v-if="account.checkout">{{ $__("Yes") }}</span>
                        <span v-else>{{ $__("No") }}</span>
                    </li>
                    <li>
                        <label>{{ $__("Renewal") }}:</label>
                        <span v-if="account.renewal">{{ $__("Yes") }}</span>
                        <span v-else>{{ $__("No") }}</span>
                    </li>
                    <li>
                        <label>{{ $__("Retries") }}:</label>
                        <span>
                            {{ account.retries }}
                        </span>
                    </li>
                    <li>
                        <label>{{ $__("Status update") }}:</label>
                        <span v-if="account.status_update">{{
                            $__("Yes")
                        }}</span>
                        <span v-else>{{ $__("No") }}</span>
                    </li>
                    <li>
                        <label>{{ $__("Timeout") }}:</label>
                        <span>
                            {{ account.timeout }}
                        </span>
                    </li>
                </ol>
            </fieldset>
            <fieldset class="action">
                <router-link
                    :to="{ name: 'SIP2AccountsList' }"
                    role="button"
                    class="cancel"
                    >{{ $__("Close") }}</router-link
                >
            </fieldset>
        </div>
    </div>
</template>

<script>
import { inject } from "vue"
import { APIClient } from "../../fetch/api-client.js"
import Toolbar from "../Toolbar.vue"
import ToolbarButton from "../ToolbarButton.vue"
import SIP2AccountResource from "./SIP2AccountResource.vue"

export default {
    extends: SIP2AccountResource,
    setup() {
        const { setConfirmationDialog, setMessage } = inject("mainStore")

        return {
            ...SIP2AccountResource.setup(),
            setConfirmationDialog,
            setMessage,
        }
    },
    data() {
        return {
            account: {
                sip_account_id: null,
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
            vm.getAccount(to.params.sip_account_id)
        })
    },
    methods: {
        async getAccount(sip_account_id) {
            const client = APIClient.sip2
            client.accounts.get(sip_account_id).then(
                account => {
                    this.account = account
                    this.initialized = true
                },
                error => {}
            )
        },
    },
    components: { Toolbar, ToolbarButton },
    name: "SIP2AccountsShow",
}
</script>
