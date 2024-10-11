import { mount } from "@cypress/vue";
const dayjs = require("dayjs"); /* Cannot use our calendar JS code, it's in an include file (!)
                                   Also note that moment.js is deprecated */

describe("Breadcrumbs tests", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Breadcrumbs", () => {
        cy.visit("/cgi-bin/koha/admin/admin-home.pl");
        cy.contains("Circulation triggers").click();
        cy.get("#breadcrumbs").contains("Administration");
        cy.get("#breadcrumbs > ol > li:nth-child(3)").contains(
            "Circulation triggers"
        );
        cy.get(".current").contains("Home");
        // use the 'New' button
        cy.contains("Add new trigger").click();
        cy.get(".current").contains("Add new trigger");
        cy.get("#breadcrumbs")
            .contains("Circulation triggers")
            .should("have.attr", "href")
            .and("equal", "/cgi-bin/koha/admin/circulation_triggers");
    });
});

describe("Circulation Triggers Component", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
    });

    it("Successfully loads the component and checks for initial elements", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Check if the component is visible
        cy.get("h1").should("contain", "Circulation triggers");

        // Check for the presence of our ordering note
        cy.get(".page-section").should(
            "contain",
            "Rules are applied from most specific to less specific"
        );
    });

    it("Selects a library and verifies the triggers table", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Select a library from the dropdown
        cy.get("#library_select .vs__selected").should("not.exist"); //no vendor pre-selected for new agreement

        cy.get("#library_select .vs__search").type("Centerville" + "{enter}", {
            force: true,
        });
        cy.get("#library_select .vs__selected").contains("Centerville");

        // Verify that the triggers table is displayed
        cy.get("#circ_triggers_tabs").should("exist");
    });

    it("Switches between trigger tabs and verifies the content", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Click on a trigger tab
        cy.get(".nav-link").contains("Trigger 1").click();

        // Verify that the corresponding trigger content is displayed
        cy.get(".tab-pane").should("contain", "Trigger content for Trigger 1");
    });

    it("Opens and closes the modal dialog", () => {
        cy.visit("/cgi-bin/koha/admin/circulation_triggers");

        // Click on a button that opens the modal
        cy.get(".modal-dialog").should("not.be.visible");
        cy.contains("Add new trigger").click();

        // Verify that the modal dialog is displayed
        cy.get(".modal-dialog").should("be.visible");

        // Close the modal dialog
        cy.get(".modal-dialog").click("topRight"); // Close the modal dialog by clicking on the top right corner
        cy.get(".modal-dialog").should("not.be.visible");
    });
});
