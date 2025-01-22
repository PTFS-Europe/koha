<template>
    <li v-if="initialized">
        <label :for="`fund_id`" :class="isRequired ? 'required' : ''"
            >{{ $__("Fund") }}:</label
        >
        <v-select
            label="name"
            :reduce="fund => fund"
            :options="fundOptions"
            @update:modelValue="setInputValues($event)"
        >
            <template v-slot:option="fund">
                {{ fund.sub_fund_id ? " -- " + fund.name : fund.name }}
            </template>
            <template #search="{ attributes, events }">
                <input
                    :required="!fund_id"
                    class="vs__search"
                    v-bind="attributes"
                    v-on="events"
                />
            </template>
        </v-select>
        <input type="hidden" name="fund_id" :value="fund_id" />
        <input type="hidden" name="sub_fund_id" :value="sub_fund_id" />
        <span v-if="isRequired" class="required">{{ $__("Required") }}</span>
        <template v-if="activeFilterRequired">
            <label for="showallbudgets" style="float: none"
                >&nbsp;&nbsp;{{ $__("Show inactive") }}:</label
            >
            <input
                type="checkbox"
                id="showallbudgets"
                @change="filterActive($event)"
            />
        </template>
    </li>
</template>

<script>
import "vue-select/dist/vue-select.css"
import { APIClient } from "../../fetch/api-client"

export default {
    props: {
        required: String,
        filterinactive: String,
    },
    data() {
        return {
            initialized: false,
            fund_id: null,
            sub_fund_id: null,
            fundOptions: [],
        }
    },
    methods: {
        async fetchFunds(inactive = false) {
            const client = APIClient.acquisition
            client.funds
                .getAll(
                    { ...(!inactive && { "me.status": true }) },
                    {},
                    { "x-koha-embed": "sub_funds" }
                )
                .then(funds => {
                    const fundList = funds.reduce((acc, fund) => {
                        acc.push(fund)
                        if (fund.sub_funds && fund.sub_funds.length > 0) {
                            acc.push(...fund.sub_funds)
                        }
                        return acc
                    }, [])
                    this.fundOptions = fundList
                })
        },
        filterActive(e) {
            if (e.target.checked) {
                this.fetchFunds(true)
            } else {
                this.fetchFunds()
            }
        },
        setInputValues(e) {
            this.fund_id = e.fund_id
            this.sub_fund_id = e.sub_fund_id || null
        },
    },
    computed: {
        isRequired() {
            if (this.required === "true" || this.required === "1") {
                return true
            }
            return false
        },
        activeFilterRequired() {
            if (this.filterinactive === "true" || this.filterinactive === "1") {
                return true
            }
            return false
        },
    },
    created() {
        this.fetchFunds().then(() => {
            this.initialized = true
        })
    },
}
</script>

<style>
form .v-select {
    display: inline-block;
    background-color: white;
    width: 30%;
}

.v-select,
input:not([type="submit"]):not([type="search"]):not([type="button"]):not(
        [type="checkbox"]
    ):not([type="radio"]),
textarea {
    border-color: rgba(60, 60, 60, 0.26);
    border-width: 1px;
    border-radius: 4px;
    min-width: 30%;
}
</style>
