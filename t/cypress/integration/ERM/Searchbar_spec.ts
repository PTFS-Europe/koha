import { mount } from "@cypress/vue";

describe("Searchbar header changes", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");
        cy.intercept(
            "GET",
            "/api/v1/erm/config",
            '{"settings":{"ERMModule":"1","ERMProviders":["local"]}}'
        );
    });

    it("Default option is agreements", () => {
        cy.visit("/cgi-bin/koha/erm/");
        cy.get("#agreement_search_tab").parent().should("have.class", "active");

        cy.visit("/cgi-bin/koha/erm/agreements");
        cy.get("#agreement_search_tab").parent().should("have.class", "active");
    });

    it("Should change to licenses when in licenses", () => {
        cy.visit("/cgi-bin/koha/erm/licenses");
        cy.get("#license_search_tab").parent().should("have.class", "active");
    });

    it("Should change to packages when in local packages", () => {
        cy.visit("/cgi-bin/koha/erm/eholdings/local/packages");
        cy.get("#package_search_tab").parent().should("have.class", "active");
    });

    it("Should change to titles when in local titles", () => {
        cy.visit("/cgi-bin/koha/erm/eholdings/local/titles");
        cy.get("#title_search_tab").parent().should("have.class", "active");
    });
});
