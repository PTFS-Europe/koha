import { defineStore } from "pinia";

export const useCircRulesStore = defineStore("circRules", {
    state: () => ({
        letters: [],
    }),
    actions: {
        splitCircRulesByTriggerNumber(rules) {
            const ruleSuffixes = ["delay", "notice", "mtt", "restrict"];
            let numberOfTabs = 1;
            const rulesPerTrigger = rules.reduce((acc, rule) => {
                const regex = /overdue_(\d+)_delay/g;
                const numberOfTriggers = Object.keys(rule).filter(key =>
                    regex.test(key)
                ).length;
                numberOfTabs = this.setNumberOfTabs(
                    numberOfTriggers,
                    numberOfTabs
                );
                const triggerNumbers = Array.from(
                    { length: numberOfTriggers },
                    (_, i) => i + 1
                );
                triggerNumbers.forEach(i => {
                    const ruleCopy = JSON.parse(JSON.stringify(rule));
                    const rulesToDelete = triggerNumbers.filter(
                        num => num !== i
                    );
                    ruleSuffixes.forEach(suffix => {
                        rulesToDelete.forEach(number => {
                            delete ruleCopy[`overdue_${number}_${suffix}`];
                        });
                    });
                    ruleCopy.triggerNumber = i;
                    acc.push(ruleCopy);
                });
                return acc;
            }, []);

            return { numberOfTabs, rulesPerTrigger };
        },
        setNumberOfTabs(triggerCount, tabCount) {
            if (triggerCount > tabCount) {
                return Array.from({ length: triggerCount }, (_, i) => i + 1);
            }
            return tabCount;
        },
    },
});
