<template>
    <div id="account_view" class="page-section">
        <table class="accounts_table">
            <tr>
                <th>{{ $__("Description") }}</th>
                <th>{{ $__("Amount") }}</th>
                <th class="centre_column"></th>
                <th>{{ $__("Description") }}</th>
                <th>{{ $__("Amount") }}</th>
            </tr>
            <tr>
                <td>{{ $__("Increase in allocation") }}</td>
                <td>
                    {{
                        formatValueWithCurrency(
                            currency,
                            data.allocation_increase
                        )
                    }}
                </td>
                <td class="centre_column"></td>
                <td>{{ $__("Encumbered") }}</td>
                <td>{{ formatValueWithCurrency(currency) }}</td>
            </tr>
            <tr>
                <td>{{ $__("Decrease in allocation") }}</td>
                <td>
                    {{
                        formatValueWithCurrency(
                            currency,
                            data.allocation_decrease
                        )
                    }}
                </td>
                <td class="centre_column"></td>
                <td>{{ $__("Awaiting payment") }}</td>
                <td>{{ formatValueWithCurrency(currency) }}</td>
            </tr>
            <tr>
                <td>{{ $__("Total allocated") }}</td>
                <td>
                    {{
                        formatValueWithCurrency(currency, data.total_allocation)
                    }}
                </td>
                <td class="centre_column"></td>
                <td>{{ $__("Expended") }}</td>
                <td>{{ formatValueWithCurrency(currency) }}</td>
            </tr>
            <tr>
                <td class="centre_column"></td>
                <td class="centre_column"></td>
                <td class="centre_column"></td>
                <td class="centre_column"></td>
                <td class="centre_column"></td>
            </tr>
            <tr>
                <td>{{ $__("Net transfers") }}</td>
                <td>
                    {{ formatValueWithCurrency(currency, data.net_transfers) }}
                </td>
                <td class="centre_column"></td>
                <td>{{ $__("Over encumbrance") }}</td>
                <td>{{ formatValueWithCurrency(currency) }}</td>
            </tr>
            <tr>
                <td>{{ $__("Total funding") }}</td>
                <td>
                    {{
                        formatValueWithCurrency(currency, data.total_allocation)
                    }}
                </td>
                <td class="centre_column"></td>
                <td>{{ $__("Over expended") }}</td>
                <td>{{ formatValueWithCurrency(currency) }}</td>
            </tr>
            <tr>
                <td>{{ $__("Cash balance") }}</td>
                <td>
                    {{
                        formatValueWithCurrency(currency, data.total_allocation)
                    }}
                </td>
                <td class="centre_column"></td>
                <td>{{ $__("Available balance") }}</td>
                <td>
                    {{
                        formatValueWithCurrency(currency, data.total_allocation)
                    }}
                </td>
            </tr>
        </table>
    </div>
</template>

<script>
import { inject } from "vue"

export default {
    setup() {
        const acquisitionsStore = inject("acquisitionsStore")
        const { formatValueWithCurrency } = acquisitionsStore

        return {
            formatValueWithCurrency,
        }
    },
    props: {
        data: Object,
        currency: String,
    },
}
</script>

<style scoped>
#account_view {
    width: 50%;
    /* margin: 0.9em 0 0; */
}
.accounts_table {
    width: 100%;
    /* border: 1px solid #BCBCBC; */
}
.accounts_table th {
    padding: 1em;
}
.accounts_table td {
    padding: 1em 0.5em;
}
.centre_column {
    background-color: #f3f4f4;
}
tbody
    tr:nth-child(odd):not(.dtrg-group, .active, .ok)
    td:not(.bg-danger, .bg-warning, .bg-info, .bg-success, .bg-primary, .centre_column) {
    background-color: white;
}
.page-section + .page-section {
    margin-top: 0em;
}
</style>
