import { defineStore } from "pinia";
import { permissionsMatrix } from "../data/permissionsMatrix";

export const useAcquisitionsStore = defineStore("acquisitions", {
    state: () => ({
        user: {
            loggedInUser: null,
            userflags: null,
        },
        libraryGroups: null,
        settings: null,
        permittedUsers: null,
        visibleGroups: null,
        owners: null,
        navigationBlocked: false,
        currentPermission: null,
        moduleList: {
            funds: { name: "Funds and ledgers", code: "funds" },
        },
        permissionsMatrix: permissionsMatrix,
        currencies: [],
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
        _mapSubGroups(group, filteredGroups, branch, groupsToCheck) {
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
                    const result = this._mapSubGroups(
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
            if (!this.libraryGroups || !this.libraryGroups.length) {
                return [];
            }
            this.libraryGroups.forEach(group => {
                const matched = this._mapSubGroups(
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
        _findBranchCodesInGroup(groups) {
            const codes = [];
            groups.forEach(group => {
                group.libraries.forEach(lib => {
                    if (!codes.find(code => code === lib.branchcode)) {
                        codes.push(lib.branchcode);
                    }
                });
            });
            return codes;
        },
        filterUsersByPermissions(
            operation,
            branchcodes = null,
            returnAll = false
        ) {
            const filteredUsers = [];
            this.permittedUsers.forEach(user => {
                user.displayName = user.firstname + " " + user.surname;
                if (returnAll) {
                    filteredUsers.push(user);
                } else {
                    const userPermitted = this.isUserPermitted(
                        operation,
                        user.permissions
                    );
                    if (userPermitted) {
                        filteredUsers.push(user);
                    }
                }
            });
            if (branchcodes) {
                return filteredUsers.filter(user =>
                    branchcodes.includes(user.branchcode)
                );
            } else {
                return filteredUsers;
            }
        },
        isUserPermitted(operation, flags) {
            const userflags = flags ? flags : this.user.userflags;
            if (!operation) return true;
            if (this.permissionsMatrix[operation].length === 0) return true;

            const { acquisition, parameters, superlibrarian } = userflags;
            if (operation === "manageSettings") {
                let checkResult = false;
                if (
                    superlibrarian ||
                    parameters === 1 ||
                    parameters.manage_sysprefs
                ) {
                    checkResult = true;
                } else {
                    checkResult = false;
                }
                return checkResult;
            }

            if (acquisition === 1 || superlibrarian) {
                return true;
            } else {
                const checks = this.permissionsMatrix[operation].map(
                    permission => {
                        if (acquisition[permission]) {
                            return true;
                        } else {
                            return false;
                        }
                    }
                );
                const failedChecks = checks.filter(check => !check).length;
                return failedChecks > 0 ? false : true;
            }
        },
        filterGroupsBasedOnOwner(e, data, groups) {
            const libGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                groups
            );
            const permittedUsers = this.filterUsersByPermissions(
                this.currentPermission
            );
            if (!e) {
                this.visibleGroups = libGroups;
                this.owners = permittedUsers;
                data.lib_group_visibility = null;
            } else {
                const { branchcode } = permittedUsers.find(
                    user => user.borrowernumber === e
                );
                this.visibleGroups = this.filterLibGroupsByUsersBranchcode(
                    branchcode,
                    groups
                );
            }
        },
        filterOwnersBasedOnGroup(e, data, groups) {
            const libGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                groups
            );
            const permittedUsers = this.filterUsersByPermissions(
                this.currentPermission
            );
            if (!e.length) {
                this.visibleGroups = libGroups;
                this.owners = permittedUsers;
                data.owner_id = null;
            } else {
                const filteredGroups = libGroups.filter(group =>
                    e.includes(group.id)
                );
                const branchcodes =
                    this._findBranchCodesInGroup(filteredGroups);
                this.owners = this.filterUsersByPermissions(
                    this.currentPermission,
                    branchcodes
                );
            }
        },
        setOwnersBasedOnPermission(permission) {
            if (this.permittedUsers) {
                this.owners = this.filterUsersByPermissions(permission);
            }
        },
        resetOwnersAndVisibleGroups(groups) {
            this.owners = this.filterUsersByPermissions(this.currentPermission);
            this.visibleGroups = this.filterLibGroupsByUsersBranchcode(
                null,
                groups
            );
        },
        getSetting(input) {
            if (typeof input === "string") {
                return this.settings[input];
            } else {
                return input.map(setting => {
                    return this.settings[setting];
                });
            }
        },
        convertSettingsToObject(settings) {
            const settingsObject = {};
            settings.forEach(setting => {
                settingsObject[setting.variable] = setting;
            });
            return settingsObject;
        },
        formatLibraryGroupIds(ids) {
            if (!ids) {
                return [];
            }
            const groups = ids.includes("|") ? ids.split("|") : [ids];
            const groupIds = groups
                .filter(group => !!group)
                .map(group => {
                    return parseInt(group);
                });
            return groupIds;
        },
        formatValueWithCurrency(currency, value) {
            const { symbol } = this.currencies.find(
                curr => curr.currency === currency
            );
            if (!value) {
                return `${symbol}0`;
            }
            if (value < 0) {
                return `-${symbol}${-value}`;
            }
            return `${symbol}${value}`;
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
        modulesEnabled() {
            const modulesEnabled = this.settings.modulesEnabled;
            return modulesEnabled.value ? modulesEnabled.value : "";
        },
        getVisibleGroups() {
            return this.visibleGroups?.length
                ? this.visibleGroups
                : this.filterLibGroupsByUsersBranchcode();
        },
        getOwners() {
            return this.owners;
        },
    },
});
