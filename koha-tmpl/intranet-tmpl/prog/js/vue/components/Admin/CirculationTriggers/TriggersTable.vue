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
                <tr
                    v-for="(rule, i) in filterCircRulesByTabNumber(
                        triggerNumber
                    )"
                    v-bind:key="'rule' + i"
                >
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
                            rule["overdue_" + triggerNumber + "_delay"] +
                            " " +
                            $__("days")
                        }}
                    </td>
                    <td>
                        {{ rule["overdue_" + triggerNumber + "_notice"] }}
                    </td>
                    <td>
                        {{
                            handleTransport(
                                rule["overdue_" + triggerNumber + "_mtt"],
                                "email"
                            )
                        }}
                    </td>
                    <td>
                        {{
                            handleTransport(
                                rule["overdue_" + triggerNumber + "_mtt"],
                                "print"
                            )
                        }}
                    </td>
                    <td>
                        {{
                            handleTransport(
                                rule["overdue_" + triggerNumber + "_mtt"],
                                "sms"
                            )
                        }}
                    </td>
                    <td>
                        {{
                            handleRestrictions(
                                rule["overdue_" + triggerNumber + "_restrict"]
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
            return value === "1" ? this.$__("Yes") : this.$__("No")
        },
        filterCircRulesByTabNumber(number) {
            return this.circRules.filter(rule => rule.triggerNumber === number)
        },
    },
}
</script>

<style></style>
