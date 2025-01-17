import { defineStore } from "pinia";
import { APIClient } from "../fetch/api-client.js";

export const usePermissionsStore = defineStore("permissions", {
    state: () => ({
        userPermissions: null,
    }),
    actions: {
        isUserPermitted(operation, permissions) {
            const userPermissions = permissions
                ? permissions
                : this.userPermissions;
            if (!operation) return true;
            if (!userPermissions) return false;

            return (
                userPermissions.hasOwnProperty(operation) &&
                userPermissions[operation]
            );
        },
        async loadUserPermissions() {
            const userPermissions =
                await APIClient.patron.userPermissions.get();
            this.userPermissions = userPermissions.permissions;
        },
    },
});
