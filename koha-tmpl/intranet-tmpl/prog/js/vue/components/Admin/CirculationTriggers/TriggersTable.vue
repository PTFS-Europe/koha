<template>
    <div class="page-section">
        <div class="page-section bg-info">
            {{
                $__(
                    "Bolid italic values denote fallback values where an override has not been set for the context."
                )
            }}
        </div>
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
                    :class="{
                        selected_rule:
                            modal && i + 1 === parseInt(ruleBeingEdited),
                    }"
                >
                    <td v-if="!modal">
                        {{
                            handleContext(
                                rule.context.patron_category_id,
                                categories,
                                "patron_category_id"
                            )
                        }}
                    </td>
                    <td v-if="!modal">
                        {{
                            handleContext(
                                rule.context.item_type_id,
                                itemTypes,
                                "item_type_id",
                                "description"
                            )
                        }}
                    </td>
                    <td v-if="modal">{{ i + 1 }}</td>

                    <!-- Delay -->
                    <td>
                        <span
                            :class="{
                                fallback: findEffectiveRule(
                                    rule,
                                    `overdue_${modal ? i + 1 : triggerNumber}_delay`
                                ).isFallback,
                            }"
                        >
                            {{
                                findEffectiveRule(
                                    rule,
                                    `overdue_${modal ? i + 1 : triggerNumber}_delay`
                                ).value +
                                " " +
                                $__("days")
                            }}
                        </span>
                    </td>

                    <!-- Notice -->
                    <td>
                        <span
                            :class="{
                                fallback: findEffectiveRule(
                                    rule,
                                    `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                ).isFallback,
                            }"
                        >
                            {{
                                handleNotice(
                                    findEffectiveRule(
                                        rule,
                                        `overdue_${modal ? i + 1 : triggerNumber}_notice`
                                    ).value
                                )
                            }}
                        </span>
                    </td>

                    <!-- Email -->
                    <td>
                        <span
                            :class="{
                                fallback: findEffectiveRule(
                                    rule,
                                    `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                ).isFallback,
                            }"
                        >
                            {{
                                handleTransport(
                                    findEffectiveRule(
                                        rule,
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ).value,
                                    "email"
                                )
                            }}
                        </span>
                    </td>

                    <!-- Print -->
                    <td>
                        <span
                            :class="{
                                fallback: findEffectiveRule(
                                    rule,
                                    `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                ).isFallback,
                            }"
                        >
                            {{
                                handleTransport(
                                    findEffectiveRule(
                                        rule,
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ).value,
                                    "print"
                                )
                            }}
                        </span>
                    </td>

                    <!-- SMS -->
                    <td>
                        <span
                            :class="{
                                fallback: findEffectiveRule(
                                    rule,
                                    `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                ).isFallback,
                            }"
                        >
                            {{
                                handleTransport(
                                    findEffectiveRule(
                                        rule,
                                        `overdue_${modal ? i + 1 : triggerNumber}_mtt`
                                    ).value,
                                    "sms"
                                )
                            }}
                        </span>
                    </td>

                    <!-- Restricts Checkouts -->
                    <td>
                        <span
                            :class="{
                                fallback: findEffectiveRule(
                                    rule,
                                    `overdue_${modal ? i + 1 : triggerNumber}_restrict`
                                ).isFallback,
                            }"
                        >
                            {{
                                handleRestrictions(
                                    findEffectiveRule(
                                        rule,
                                        `overdue_${modal ? i + 1 : triggerNumber}_restrict`
                                    ).value
                                )
                            }}
                        </span>
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
                : "";
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
        findEffectiveRule(ruleSet, key) {
            // Check if the current rule's value for the key is null
            if (ruleSet[key] === null) {
                // Filter rules to only those with non-null values for the specified key
                const relevantRules = this.circRules.filter(
                    rule => rule[key] !== null
                );

                // Function to calculate specificity score
                const getSpecificityScore = ruleContext => {
                    let score = 0;
                    if (
                        ruleContext.library_id !== "*" &&
                        ruleContext.library_id === ruleSet.library_id
                    )
                        score += 4;
                    if (
                        ruleContext.patron_category_id !== "*" &&
                        ruleContext.patron_category_id ===
                            ruleSet.patron_category_id
                    )
                        score += 2;
                    if (
                        ruleContext.item_type_id !== "*" &&
                        ruleContext.item_type_id === ruleSet.item_type_id
                    )
                        score += 1;
                    return score;
                };

                // Sort the rules based on specificity score, descending
                const sortedRules = relevantRules.sort((a, b) => {
                    return (
                        getSpecificityScore(b.context) -
                        getSpecificityScore(a.context)
                    );
                });

                // If no rule found, return null
                if (sortedRules.length === 0) {
                    return { value: null, isFallback: true };
                }

                // Get the value from the most specific rule
                const bestRule = sortedRules[0];
                return { value: bestRule[key], isFallback: true };
            } else {
                // If the current rule's value is not null, use it directly
                return { value: ruleSet[key], isFallback: false };
            }
        },
    },
};
</script>

<style scoped>
.selected_rule > td {
    background-color: yellow !important;
}
.fallback {
    font-style: italic;
    font-weight: bold;
}
.actions a {
    margin-right: 5px;
}
</style>
