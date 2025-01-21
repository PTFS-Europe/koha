describe("Acquisitions menu", () => {
    beforeEach(() => {
        cy.login();
        cy.title().should("eq", "Koha staff interface");

        cy.query(
            "UPDATE systempreferences SET value=0 WHERE variable='EDIFACT'"
        );
        cy.query(
            "UPDATE systempreferences SET value=0 WHERE variable='MarcOrderingAutomation'"
        );
    });

    it("Should render a left menu", () => {
        cy.visit("/cgi-bin/koha/acqui/acqui-home.pl");
        cy.get("#navmenulist").should("be.visible");
        cy.get("#navmenulist a").should("have.length", 14);
    });

    it("Should show/hide links based on sysprefs", () => {
        cy.visit("/cgi-bin/koha/acqui/acqui-home.pl");
        cy.get("#navmenulist").should("be.visible");

        cy.query(
            "UPDATE systempreferences SET value=1 WHERE variable='EDIFACT'"
        );
        cy.get("#navmenulist a").should("have.length", 17);
    });

    it("Should show/hide links based on permissions", () => {
        cy.visit("/cgi-bin/koha/acqui/acqui-home.pl");
        cy.get("#navmenulist").should("be.visible");

        cy.query("UPDATE borrowers SET flags=2052 WHERE borrowernumber=51");
        cy.get("#navmenulist a").should("have.length", 8);
    });
    it("Should correctly apply the 'current' class", () => {
        cy.visit("/cgi-bin/koha/acqui/acqui-home.pl");
        cy.get("#navmenulist").should("be.visible");

        cy.get("#navmenulist a")
            .contains("Acquisitions home")
            .should("have.class", "current");
        cy.get("#navmenulist a").contains("Budgets").click();
        cy.get("#navmenulist a")
            .contains("Budgets")
            .should("have.class", "current");
    });
});
