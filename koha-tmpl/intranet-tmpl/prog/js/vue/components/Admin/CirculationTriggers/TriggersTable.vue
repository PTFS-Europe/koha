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
                    {{ $__("Rule") }}
                </th>
                <th>
                    {{ $__("Delay") }}
                </th>
                <th>
                    {{ $__("Notice") }}
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
                <th v-if="!modal">
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
                        {{
                            handleContext(
                                rule.context.patron_category_id,
                                categories,
                                "patron_category_id"
                            )
                        }}
                    </td>
                    <td
                        v-if="!modal"
                        :class="
                            modal && i + 1 === parseInt(ruleBeingEdited)
                                ? 'selected_rule'
                                : ''
                        "
                    >
                        {{
                            handleContext(
                                rule.context.item_type_id,
                                itemTypes,
                                "item_type_id",
                                "description"
                            )
                        }}
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
                            ]
                                ? rule[
                                      "overdue_" +
                                          (modal ? i + 1 : triggerNumber) +
                                          "_delay"
                                  ] +
                                  " " +
                                  $__("days")
                                : 0 + " " + $__("days")
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
                            handleNotice(
                                rule[
                                    "overdue_" +
                                        (modal ? i + 1 : triggerNumber) +
                                        "_notice"
                                ]
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
                    <td v-if="!modal" class="actions">
                        <router-link
                            :to="{
                                name: 'CirculationTriggersFormEdit',
                                query: {
                                    library_id: rule.context.library_id,
                                    item_type_id: rule.context.item_type_id,
                                    patron_category_id:
                                        rule.context.patron_category_id,
                                    triggerNumber,
                                },
                            }"
                            class="btn btn-default btn-xs"
                            ><i class="fa-solid fa-pencil"></i>
                            Edit</router-link
                        >
                    </td>
                </tr>
            </tbody>
        </table>
    </div>
</template>

<script>
export default {
    props: [
        "circRules",
        "triggerNumber",
        "modal",
        "ruleBeingEdited",
        "categories",
        "itemTypes",
        "letters",
    ],
    methods: {
        handleContext(value, data, type, displayProperty = "name") {
            const item = data.find(item => item[type] === value);
            return item[displayProperty];
        },
        handleTransport(value, type) {
            return value
                ? value.includes(type)
                    ? this.$__("Yes")
                    : this.$__("No")
                : this.$__("Default");
        },
        handleRestrictions(value) {
            return value === "1" ? this.$__("Yes") : this.$__("No");
        },
        filterCircRulesByTabNumber(number) {
            if (this.modal) return this.circRules;
            return this.circRules.filter(
                rule =>
                    rule.triggerNumber === number &&
                    (rule[`overdue_${number}_delay`] ||
                        rule[`overdue_${number}_notice`] ||
                        rule[`overdue_${number}_mtt`] ||
                        rule[`overdue_${number}_restrict`])
            );
        },
        handleNotice(notice) {
            const letter = this.letters.find(letter => letter.code === notice);
            return letter ? letter.name : notice;
        },
    },
};
</script>

<style scoped>
.selected_rule {
    background-color: yellow !important;
}

.actions a {
    margin-right: 5px;
}
</style>
