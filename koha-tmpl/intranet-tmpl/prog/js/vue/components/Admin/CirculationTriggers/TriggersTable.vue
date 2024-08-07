<template>
    <div class="page-section">
        <table>
            <thead>
                <th>
                    {{ $__("Library") }}
                </th>
                <th>
                    {{ $__("Patron category") }}
                </th>
                <th>
                    {{ $__("Item type") }}
                </th>
                <th>
                    {{ $__("Delay") }}
                </th>
                <th>
                    {{ $__("Letter code") }}
                </th>
                <th>
                    {{ $__("Email") }}
                </th>
                <th>
                    {{ $__("Print") }}
                </th>
                <th>
                    {{ $__("SMS") }}
                </th>
                <th>
                    {{ $__("Restricts checkouts") }}
                </th>
            </thead>
            <tbody>
                <tr v-for="(rule, i) in circRules" v-bind:key="'rule' + i">
                    <td>
                        {{ handleContext(rule.context.library_id) }}
                    </td>
                    <td>
                        {{ handleContext(rule.context.patron_category_id) }}
                    </td>
                    <td>
                        {{ handleContext(rule.context.item_type_id) }}
                    </td>
                    <td>
                        {{
                            rule["overdue_delay_" + triggerNumber] +
                            " " +
                            $__("days")
                        }}
                    </td>
                    <td>
                        {{ rule["overdue_template_" + triggerNumber] }}
                    </td>
                    <td>
                        {{
                            handleTransport(
                                rule["overdue_transports_" + triggerNumber],
                                "email"
                            )
                        }}
                    </td>
                    <td>
                        {{
                            handleTransport(
                                rule["overdue_transports_" + triggerNumber],
                                "print"
                            )
                        }}
                    </td>
                    <td>
                        {{
                            handleTransport(
                                rule["overdue_transports_" + triggerNumber],
                                "sms"
                            )
                        }}
                    </td>
                    <td>
                        {{
                            handleRestrictions(
                                rule["overdue_restricts_" + triggerNumber]
                            )
                        }}
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</template>

<script>
export default {
    props: ["circRules", "triggerNumber"],
    methods: {
        handleContext(value) {
            if (value === "*") {
                return this.$__("All")
            }
            return value
        },
        handleTransport(value, type) {
            return value.includes(type) ? this.$__("Yes") : this.$__("No")
        },
        handleRestrictions(value) {
            return value ? this.$__("Yes") : this.$__("No")
        },
    },
}
</script>

<style></style>
