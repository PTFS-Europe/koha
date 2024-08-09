<template>
    <div class="page-section">
        <table>
            <thead>
                <th v-if="!modal">
                    {{ $__("Patron category") }}
                </th>
                <th v-if="!modal">
                    {{ $__("Item type") }}
                </th>
                <th v-if="modal">
                    {{ $__("Notice") }}
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
                    <td
                        v-if="!modal"
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{ handleContext(rule.context.patron_category_id) }}
                    </td>
                    <td
                        v-if="!modal"
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{ handleContext(rule.context.item_type_id) }}
                    </td>
                    <td
                        v-if="modal"
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{ i + 1 }}
                    </td>
                    <td
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{
                            rule[
                                "overdue_" +
                                    (modal ? i + 1 : triggerNumber) +
                                    "_delay"
                            ] +
                            " " +
                            $__("days")
                        }}
                    </td>
                    <td
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{
                            rule[
                                "overdue_" +
                                    (modal ? i + 1 : triggerNumber) +
                                    "_notice"
                            ]
                        }}
                    </td>
                    <td
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{
                            handleTransport(
                                rule[
                                    "overdue_" +
                                        (modal ? i + 1 : triggerNumber) +
                                        "_mtt"
                                ],
                                "email"
                            )
                        }}
                    </td>
                    <td
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{
                            handleTransport(
                                rule[
                                    "overdue_" +
                                        (modal ? i + 1 : triggerNumber) +
                                        "_mtt"
                                ],
                                "print"
                            )
                        }}
                    </td>
                    <td
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{
                            handleTransport(
                                rule[
                                    "overdue_" +
                                        (modal ? i + 1 : triggerNumber) +
                                        "_mtt"
                                ],
                                "sms"
                            )
                        }}
                    </td>
                    <td
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{
                            handleRestrictions(
                                rule[
                                    "overdue_" +
                                        (modal ? i + 1 : triggerNumber) +
                                        "_restrict"
                                ]
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
                                    triggerNumber: i + 1,
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
    props: ["circRules", "triggerNumber", "modal", "ruleBeingEdited"],
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
            if (this.modal) return this.circRules
            return this.circRules.filter(rule => rule.triggerNumber === number)
        },
    },
}
</script>

<style scoped>
.selected_rule {
    background-color: yellow !important;
}
</style>
