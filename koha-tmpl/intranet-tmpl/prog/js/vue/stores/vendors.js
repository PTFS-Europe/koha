import { defineStore } from "pinia";

export const useVendorStore = defineStore("vendors", {
    state: () => ({
        vendors: [],
        currencies: [],
        gstValues: [],
        libraryGroups: null,
        visibleGroups: null,
        user: {
            loggedInUser: null,
            userflags: null,
        },
        config: {
            settings: {
                edifact: false,
            },
        },
    }),
    actions: {
        determineBranch(code) {
            if (code) {
                return code;
            }
            const {
                loggedInUser: { loggedInBranch, branchcode },
            } = this.user;
            return loggedInBranch ? loggedInBranch : branchcode;
        },
        _matchSubGroups(group, filteredGroups, branch, groupsToCheck) {
            let matched = false;
            if (group.libraries.find(lib => lib.branchcode === branch)) {
                if (
                    groupsToCheck &&
                    groupsToCheck.length &&
                    groupsToCheck.includes(group.id)
                ) {
                    filteredGroups[group.id] = group;
                    matched = true;
                }
                if (!groupsToCheck || groupsToCheck.length === 0) {
                    filteredGroups[group.id] = group;
                    matched = true;
                }
            }
            if (group.subGroups && group.subGroups.length) {
                group.subGroups.forEach(grp => {
                    const result = this._matchSubGroups(
                        grp,
                        filteredGroups,
                        branch,
                        groupsToCheck
                    );
                    matched = matched ? matched : result;
                });
            }
            return matched;
        },
        filterLibGroupsByUsersBranchcode(branchcode, groupsToCheck) {
            const branch = this.determineBranch(branchcode);
            const filteredGroups = {};
            if (!this.libraryGroups) {
                return [];
            }
            this.libraryGroups.forEach(group => {
                const matched = this._matchSubGroups(
                    group,
                    filteredGroups,
                    branch,
                    groupsToCheck
                );
                // If a sub group has been matched but the parent level group did not, then we should add the parent level group as well
                // This happens when a parent group doesn't have any branchcodes assigned to it, only sub groups
                if (
                    matched &&
                    !Object.keys(filteredGroups).find(id => id === group.id)
                ) {
                    filteredGroups[group.id] = group;
                }
            });
            return Object.keys(filteredGroups)
                .map(key => {
                    return filteredGroups[key];
                })
                .sort((a, b) => a.id - b.id);
        },
        formatLibraryGroupIds(ids) {
            if (!ids) {
                return [];
            }
            const groups = ids.includes("|") ? ids.split("|") : [ids];
            const groupIds = groups.map(group => {
                return parseInt(group);
            });
            return groupIds;
        },
        setLibraryGroups(groups) {
            if (!groups?.length) {
                return;
            }
            const topLevelGroups = groups.filter(
                group => !group.parent_id && group.ft_acquisitions
            );
            if (!topLevelGroups?.length) {
                return;
            }
            this.libraryGroups = topLevelGroups.map(group => {
                return this._mapLibraryGroup(group, groups);
            });
        },
        _mapLibraryGroup(group, groups) {
            const groupInfo = {
                id: group.id,
                title: group.title,
                libraries: [],
                subGroups: [],
            };
            const libsOrSubGroups = groups.filter(
                grp => grp.parent_id == group.id
            );
            libsOrSubGroups.forEach(libOrSubGroup => {
                if (libOrSubGroup.branchcode) {
                    groupInfo.libraries.push(libOrSubGroup);
                } else {
                    const subGroupInfo = this._mapLibraryGroup(
                        libOrSubGroup,
                        groups,
                        true
                    );
                    groupInfo.subGroups.push(subGroupInfo);
                }
            });
            groupInfo.subGroups.forEach(subGroup => {
                subGroup.libraries.forEach(lib => {
                    if (
                        !groupInfo.libraries.find(
                            g => g.branchcode === lib.branchcode
                        )
                    ) {
                        groupInfo.libraries.push(lib);
                    }
                });
            });
            return groupInfo;
        },
    },
    getters: {
        getVisibleGroups() {
            return this.visibleGroups?.length
                ? this.visibleGroups
                : this.filterLibGroupsByUsersBranchcode();
        },
    },
});
