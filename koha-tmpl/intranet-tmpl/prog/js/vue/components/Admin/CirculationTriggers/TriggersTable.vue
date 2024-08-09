<template>
    <div class="page-section">
        <table>
            <thead>
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
                <th>
                    {{ $__("Actions") }}
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
                    <td>
                        <router-link
                            :to="{
                                name: 'CirculationTriggersFormEdit',
                                query: {
                                    library_id: rule.context.library_id,
                                    item_type_id: rule.context.item_type_id,
                                    patron_category_id:
                                        rule.context.patron_category_id,
                                },
                            }"
                            >Edit</router-link
                        >
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
