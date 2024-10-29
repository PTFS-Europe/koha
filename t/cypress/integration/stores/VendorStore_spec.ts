import { setActivePinia, createPinia } from "pinia";
import { useVendorStore } from "../../../../koha-tmpl/intranet-tmpl/prog/js/vue/stores/vendors";

describe("VendorStore", () => {
    beforeEach(() => {
        setActivePinia(createPinia());
    });
    it("Should determine which branch to use when calling determineBranch()", () => {
        const store = useVendorStore();

        store.user.loggedInUser = { loggedInBranch: "XYZ", branchcode: "123" };
        const branch = store.determineBranch("ABC");
        expect(branch).to.eq("ABC");

        store.user.loggedInUser = { loggedInBranch: "XYZ", branchcode: "123" };
        const branch2 = store.determineBranch();
        expect(branch2).to.eq("XYZ");

        store.user.loggedInUser = { loggedInBranch: null, branchcode: "123" };
        const branch3 = store.determineBranch();
        expect(branch3).to.eq("123");
    });
    it("Should filter library groups by users branchcode when calling filterLibGroupsByUsersBranchcode", () => {
        const store = useVendorStore();

        store.setLibraryGroups(cy.getLibraryGroups());
        const filteredGroups = store.filterLibGroupsByUsersBranchcode("TPL");

        expect(filteredGroups).to.have.length(3);
        expect(filteredGroups[0].title).to.eq("LibGroup2");
        expect(filteredGroups[1].title).to.eq("LibGroup2 SubGroupC");
        expect(filteredGroups[2].title).to.eq("LibGroup2 SubGroupC SubGroup2");

        const filteredGroupsTwo = store.filterLibGroupsByUsersBranchcode(
            "MPL",
            filteredGroups.map(grp => grp.id)
        );
        expect(filteredGroupsTwo).to.have.length(2);
        expect(filteredGroupsTwo[0].title).to.eq("LibGroup2");
        expect(filteredGroupsTwo[1].title).to.eq("LibGroup2 SubGroupC");
    });
    it("Should format library groups ids when calling formatLibraryGroupIds", () => {
        const store = useVendorStore();

        let ids = store.formatLibraryGroupIds("1|2|3");
        expect(ids).to.deep.eql([1, 2, 3]);

        ids = store.formatLibraryGroupIds("1");
        expect(ids).to.eql([1]);
    });
    it("Should set library groups when calling setLibraryGroups", () => {
        const store = useVendorStore();

        store.setLibraryGroups(cy.getLibraryGroups());
        const libraryGroups = store.libraryGroups;
        expect(libraryGroups).to.have.length(3);
        expect(libraryGroups[0].title).to.eq("LibGroup1");
        expect(libraryGroups[1].title).to.eq("LibGroup2");
        expect(libraryGroups[2].title).to.eq("LibGroup3");

        expect(libraryGroups[0].libraries).to.have.length(2);
        expect(libraryGroups[0].subGroups).to.have.length(2);
        expect(libraryGroups[0].subGroups[0].libraries).to.have.length(2);
        expect(libraryGroups[0].subGroups[0].subGroups).to.have.length(2);

        expect(libraryGroups[1].libraries).to.have.length(3);
        expect(libraryGroups[1].subGroups).to.have.length(3);
        expect(libraryGroups[1].subGroups[0].libraries).to.have.length(2);
        expect(libraryGroups[1].subGroups[0].subGroups).to.have.length(2);
    });
});
