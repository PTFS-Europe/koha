# RELEASE NOTES FOR KOHA 23.11.04
25 Mar 2024

Koha is the first free and open source software library automation
package (ILS). Development is sponsored by libraries of varying types
and sizes, volunteers, and support companies from around the world. The
website for the Koha project is:

- [Koha Community](http://koha-community.org)

Koha 23.11.04 can be downloaded from:

- [Download](http://download.koha-community.org/koha-23.11.04.tar.gz)

Installation instructions can be found at:

- [Koha Wiki](http://wiki.koha-community.org/wiki/Installation_Documentation)
- OR in the INSTALL files that come in the tarball

Koha 23.11.04 is a bugfix/maintenance release with security fixes.

It includes 5 security bugfixes, 75 other bugfixes and 5 enhancements.

**System requirements**

You can learn about the system components (like OS and database) needed for running Koha on the [community wiki](https://wiki.koha-community.org/wiki/System_requirements_and_recommendations).


#### Security bugs

- [24879](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=24879) Add missing authentication checks
- [35960](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35960) XSS in staff login form
- [36244](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36244) Template toolkit syntax not escaped in letter templates
- [36322](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36322) Can run docs/**/*.pl from the UI
- [36323](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36323) koha_perl_deps.pl can be run from the UI

## Bugfixes

### About

#### Other bugs fixed

- [36134](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36134) Elasticsearch authentication using userinfo parameter crashes about.pl

### Accessibility

#### Other bugs fixed

- [36140](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36140) Wrong for attribute on Invoice number: label in invoice.tt

### Acquisitions

#### Critical bugs fixed

- [35892](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35892) Fallback to GetMarcPrice in addorderiso2907 no longer works
- [35913](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35913) Item order prices do not fall back to MarcFieldsToOrder if not set by MarcItemFieldsToOrder
- [36047](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36047) Apostrophe in suggestion status reason blocks order receipt
- [36233](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36233) Cannot search invoices if too many vendors

#### Other bugs fixed

- [35398](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35398) EDI: Fix support for LRP (Library Rotation Plan) for Koha with Stock Rotation enabled
- [35911](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35911) Archived suggestions show in patron's account
  >This fixes an unintended change introduced in Koha 22.11. Archived suggestions are now no longer shown on the patron's account page in the staff interface.
- [35916](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35916) Purchase suggestions bibliographic filter should be a "contains" search

### Architecture, internals, and plumbing

#### Critical bugs fixed

- [35819](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35819) "No job found" error for BatchUpdateBiblioHoldsQueue (race condition)

#### Other bugs fixed

- [33898](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=33898) background_jobs_worker.pl may leave defunct children processes for extended periods of time
- [35248](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35248) Bookings needs unit tests
- [35718](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35718) Remove ES6 warnings from JavaScript system preferences
  >This removes some warnings when entering JavaScript in UserJS system preferences and library specific OPAC JS, when using ECMAScript 6 features/syntax.
- [35921](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35921) Improve performance of acquisitions start page when there are many budgets
- [35950](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35950) Move the handling of statistics patron logic out of CanBookBeIssued
- [36000](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36000) Fix CGI::param called in list context from catalogue/search.pl
- [36056](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36056) Clarify subpermissions check behavior in C4::Auth
- [36088](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36088) Remove useless code form opac-account-pay.pl
- [36170](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36170) Wrong warning in memberentry
- [36176](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36176) [23.11 and below] We need tests to check for 'cud-' operations in stable branches (pre-24.05)
- [36212](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36212) transferbook should not look for items without barcode

### Authentication

#### Critical bugs fixed

- [34755](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=34755) Error authenticating to external OpenID Connect (OIDC) identity provider : wrong_csrf_token

#### Other bugs fixed

- [36098](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36098) Create Koha::Session module

### Cataloging

#### Other bugs fixed

- [29522](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=29522) Bib record not correctly updated when merging identical authorities with LinkerModule set to First Match
- [32029](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=32029) Automatic item modifications by age missing biblio table
- [34234](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=34234) Item groups dropdown in detail page modal does not respect display order
- [35554](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35554) Authority search popup is only 700px
- [35963](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35963) Problem using some filters in the bundled items table

### Circulation

#### Critical bugs fixed

- [36100](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36100) Regression in bookings edit
- [36175](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36175) Checking out items that are booked doesn't quite work

#### Other bugs fixed

- [35357](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35357) Item not removed from holds queue when checked out to a different patron
- [35469](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35469) Cannot create bookings without circulation permissions
- [35532](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35532) Use of calendar for date range in bookings is not clear
  >This updates the bookings feature to make selecting the booking period clearer:
  >- Changes field label from 'Period' to 'Booking dates'
  >- Adds a hint added to indicate that you need to select a start and end date ('Select the booking start and end date')
  >- Removes the date shortcut options from the date picker, as they do not make sense for bookings
- [35773](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35773) Cannot create bookings without edit_borrowers, label_creator, routing or order_manage permissions
- [35840](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35840) Local use is double-counted when using both RecordLocalUseOnReturn and statistical patrons
- [35924](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35924) The 'checkin slip' button should not be available for patrons whose privacy is set to never
- [35983](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35983) Library specific refund lost item replacement fee cannot be 'refund_unpaid'
- [36091](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36091) Spelling: Use "card number" instead of cardnumber in text

### Command-line Utilities

#### Other bugs fixed

- [36009](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36009) Document koha-worker --queue elastic_index

### Hold requests

#### Other bugs fixed

- [35997](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35997) Cancelling a hold should remove the hold from the queue
- [36103](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36103) Remove the "Cancel hold" link for item level holds

### ILL

#### Other bugs fixed

- [36130](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36130) ILL batches table not showing all batches

### Installation and upgrade (command-line installer)

#### Critical bugs fixed

- [35473](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35473) Core bookings and room reservations plugin tables clash

### Installation and upgrade (web-based installer)

#### Critical bugs fixed

- [36232](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36232) Error fixing OAI-PMH:AutoUpdateSetsEmbedItemData syspref name on the DB

### Notices

#### Critical bugs fixed

- [31427](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=31427) Automatic renewal errors should come before many other renewal errors

### OPAC

#### Other bugs fixed

- [35538](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35538) List of libraries on OPAC self registration form should sort by branchname rather than branchcode
- [35952](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35952) Removed unnecessary  line in opac-blocked.pl
- [36004](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36004) Typo in "Your concern was successfully submitted" OPAC text
- [36032](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36032) The "Next" pagination button has a double instead of a single angle

  **Sponsored by** *Karlsruhe Institute of Technology (KIT)*
- [36070](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36070) "Place recall" hover styling on OPAC not consistent

### Patrons

#### Critical bugs fixed

- [35796](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35796) Patron password expiration date lost when patron edited by superlibrarian

#### Other bugs fixed

- [36076](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36076) paycollect.tt is missing permission checks for manual credit and invoice
- [36292](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36292) 'See all charges' hyperlink to view guarantee fees is not linked correctly
- [36298](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36298) In patrons search road type authorized value code displayed in patron address

### REST API

#### Other bugs fixed

- [36066](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36066) REST API: We should only allow deleting cancelled order lines
- [36329](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36329) Transfer limits should respect `BranchTransferLimitsType`

### Reports

#### Critical bugs fixed

- [31988](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=31988) manager.pl is only user for "Catalog by item type" report

#### Other bugs fixed

- [35949](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35949) Useless code pointing to branchreserves.pl in request.tt

### Staff interface

#### Critical bugs fixed

- [35935](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35935) Wrong branch picked after an incorrect login

#### Other bugs fixed

- [36005](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36005) Typo in "Your concern was successfully submitted" in staff interface
- [36099](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36099) JS error in console on non-existent biblio record
- [36150](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36150) Circulation home page styling does not match Cataloging home page styling
  >This fixes the styling of the circulation home page for the staff interface. It is now consistent with the cataloging home page, and includes wider side margins.
- [36215](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36215) Bookings calendar only shows bookings within RESTdefaultPageSize

### Templates

#### Critical bugs fixed

- [36332](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36332) JS error on moremember

#### Other bugs fixed

- [35351](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35351) Adjust basket details template to avoid showing empty page-section
  >This removes the empty white section in acquisitions for a basket with no orders.
- [35397](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35397) SIP2AddOpacMessagesToScreenMessage syspref description issue
- [35422](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35422) Unexpected translation string for Suggestions template
- [35934](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35934) Items in transit show as both in-transit and Available on holdings list
- [36157](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36157) Links in the "Run with template" dropdown at guided_reports.pl have odd formatting
- [36158](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36158) Text on the "Show SQL code" button at guided_reports.pl breaks if report notice templates exist
- [36224](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36224) It looks like spsuggest functionality was removed years ago, but the templates still refer to it

### Test Suite

#### Critical bugs fixed

- [36356](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36356) FrameworkPlugin.t does not rollback properly

#### Other bugs fixed

- [32671](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=32671) basic_workflow.t is failing on slow servers
- [36010](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36010) Items/AutomaticItemModificationByAge.t is failing
- [36277](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36277) t/db_dependent/api/v1/transfer_limits.t  is failing

## Enhancements 

### Architecture, internals, and plumbing

#### Enhancements

- [35388](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35388) Add comment to circ/transfers_to_send.pl about limited use in stock rotation context
- [35955](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35955) New CSRF token generated everytime we need one

### Cataloging

#### Enhancements

- [36156](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=36156) Duplicate selected value when a field or subfield is cloned

### REST API

#### Enhancements

- [33036](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=33036) REST API: Merge biblio records
  >A new endpoint of REST API /biblios, to merge two bibliographic records. You need to pass parameters with a json file.
  >Complete endpoint: <base_url>/api/v1/biblios/<biblo_id>/merge
  >Parametes of json file:
  >- biblio_id_to_merge (mandatory)
  >- rules (optional)
  >- framework_to_use (optional)
  >- datarecord (optional)
  >More info in the  Swagger/OpenAPI Specification of the API

  **Sponsored by** *Technische Hochschule Wildau*

### Templates

#### Enhancements

- [35426](http://bugs.koha-community.org/bugzilla3/show_bug.cgi?id=35426) Improve layout of bookings modal form

## Documentation

The Koha manual is maintained in Sphinx. The home page for Koha
documentation is

- [Koha Documentation](http://koha-community.org/documentation/)
As of the date of these release notes, the Koha manual is available in the following languages:

- [Chinese (Traditional)](https://koha-community.org/manual/23.11//html/) (63%)
- [English](https://koha-community.org/manual/23.11//html/) (100%)
- [English (USA)](https://koha-community.org/manual/23.11/en/html/)
- [French](https://koha-community.org/manual/23.11/fr/html/) (41%)
- [German](https://koha-community.org/manual/23.11/de/html/) (40%)
- [Hindi](https://koha-community.org/manual/23.11/hi/html/) (75%)

The Git repository for the Koha manual can be found at

- [Koha Git Repository](https://gitlab.com/koha-community/koha-manual)

## Translations

Complete or near-complete translations of the OPAC and staff
interface are available in this release for the following languages:
<div style="column-count: 2;">

- Arabic (ar_ARAB) (69%)
- Armenian (hy_ARMN) (100%)
- Bulgarian (bg_CYRL) (99%)
- Chinese (Traditional) (91%)
- Czech (68%)
- Dutch (77%)
- English (100%)
- English (New Zealand) (64%)
- English (USA)
- Finnish (99%)
- French (99%)
- French (Canada) (96%)
- German (99%)
- German (Switzerland) (52%)
- Greek (52%)
- Hindi (99%)
- Italian (84%)
- Norwegian Bokmål (76%)
- Persian (fa_ARAB) (91%)
- Polish (95%)
- Portuguese (Brazil) (92%)
- Portuguese (Portugal) (88%)
- Russian (90%)
- Slovak (62%)
- Spanish (99%)
- Swedish (86%)
- Telugu (71%)
- Turkish (80%)
- Ukrainian (74%)
- hyw_ARMN (generated) (hyw_ARMN) (65%)
</div>

Partial translations are available for various other languages.

The Koha team welcomes additional translations; please see

- [Koha Translation Info](http://wiki.koha-community.org/wiki/Translating_Koha)

For information about translating Koha, and join the koha-translate 
list to volunteer:

- [Koha Translate List](http://lists.koha-community.org/cgi-bin/mailman/listinfo/koha-translate)

The most up-to-date translations can be found at:

- [Koha Translation](http://translate.koha-community.org/)

## Release Team

The release team for Koha 23.11.04 is


- Release Manager: Katrin Fischer

- Release Manager assistants:
  - Tomás Cohen Arazi
  - Martin Renvoize
  - Jonathan Druart

- QA Manager: Marcel de Rooy

- QA Team:
  - Marcel de Rooy
  - Julian Maurice
  - Lucas Gass
  - Victor Grousset
  - Kyle M Hall
  - Nick Clemens
  - Martin Renvoize
  - Tomás Cohen Arazi
  - Aleisha Amohia
  - Emily Lamancusa
  - David Cook
  - Jonathan Druart
  - Pedor Amorim

- Topic Experts:
  - UI Design -- Owen Leonard
  - Zebra -- Fridolin Somers
  - REST API -- Tomás Cohen Arazi
  - ERM -- Matt Blenkinsop
  - ILL -- Pedro Amorim
  - SIP2 -- Matthias Meusburger
  - CAS -- Matthias Meusburger

- Bug Wranglers:
  - Aleisha Amohia
  - Indranil Das Gupta

- Packaging Managers:
  - Mason James
  - Indranil Das Gupta
  - Tomás Cohen Arazi

- Documentation Manager: Aude Charillon

- Documentation Team:
  - Caroline Cyr La Rose
  - Kelly McElligott
  - Philip Orr
  - Marie-Luce Laflamme
  - Lucy Vaux-Harvey

- Translation Manager: Jonathan Druart


- Wiki curators: 
  - Thomas Dukleth
  - Katrin Fischer

- Release Maintainers:
  - 23.11 -- Fridolin Somers
  - 23.05 -- Lucas Gass
  - 22.11 -- Frédéric Demians
  - 22.05 -- Danyon Sewell

- Release Maintainer assistants:
  - 22.05 -- Wainui Witika-Park

## Credits

We thank the following libraries, companies, and other institutions who are known to have sponsored
new features in Koha 23.11.04
<div style="column-count: 2;">

- Karlsruhe Institute of Technology (KIT)
- Technische Hochschule Wildau
</div>

We thank the following individuals who contributed patches to Koha 23.11.04
<div style="column-count: 2;">

- Pedro Amorim (6)
- Tomás Cohen Arazi (9)
- Nick Clemens (8)
- David Cook (6)
- Jonathan Druart (27)
- Magnus Enger (1)
- Laura Escamilla (3)
- Katrin Fischer (2)
- Lucas Gass (12)
- Victor Grousset (2)
- Thibaud Guillot (1)
- Kyle M Hall (12)
- Andreas Jonsson (2)
- Emily Lamancusa (1)
- Owen Leonard (5)
- Julian Maurice (6)
- Martin Renvoize (30)
- Marcel de Rooy (12)
- Fridolin Somers (9)
- Raphael Straub (1)
- Zeno Tajoli (1)
- Lari Taskula (1)
- Shi Yao Wang (2)
</div>

We thank the following libraries, companies, and other institutions who contributed
patches to Koha 23.11.04
<div style="column-count: 2;">

- Athens County Public Libraries (5)
- BibLibre (16)
- Bibliotheksservice-Zentrum Baden-Württemberg (BSZ) (2)
- ByWater-Solutions (35)
- Cineca (1)
- Hypernova Oy (1)
- kit.edu (1)
- Koha Community Developers (29)
- Kreablo AB (2)
- Libriotech (1)
- montgomerycountymd.gov (1)
- Prosentient Systems (6)
- PTFS-Europe (36)
- Rijksmuseum (12)
- Solutions inLibro inc (2)
- Theke Solutions (9)
</div>

We also especially thank the following individuals who tested patches
for Koha
<div style="column-count: 2;">

- Pedro Amorim (6)
- Tomás Cohen Arazi (10)
- Nick Clemens (19)
- David Cook (1)
- Jonathan Druart (13)
- Magnus Enger (2)
- Katrin Fischer (133)
- Andrew Fuerste-Henry (3)
- matthias le gac (1)
- Lucas Gass (2)
- Victor Grousset (25)
- Sophie Halden (1)
- Kyle M Hall (11)
- Andrew Fuerste Henry (7)
- Olivier Hubert (1)
- Barbara Johnson (2)
- Jan Kissig (1)
- Emily Lamancusa (6)
- Sam Lau (1)
- Brendan Lawlor (3)
- Owen Leonard (9)
- Julian Maurice (9)
- Kelly McElligott (1)
- David Nind (39)
- Philip Orr (1)
- Barbara Petritsch (1)
- Martin Renvoize (26)
- Marcel de Rooy (27)
- Lisette Scheer (1)
- Fridolin Somers (148)
- Edith Speller (1)
- Mohd Hafiz Yusoff (2)
- Anneli Österman (1)
</div>





We regret any omissions.  If a contributor has been inadvertently missed,
please send a patch against these release notes to koha-devel@lists.koha-community.org.

## Revision control notes

The Koha project uses Git for version control.  The current development
version of Koha can be retrieved by checking out the master branch of:

- [Koha Git Repository](https://git.koha-community.org/koha-community/koha)

The branch for this version of Koha and future bugfixes in this release
line is 23.11.x-security.

## Bugs and feature requests

Bug reports and feature requests can be filed at the Koha bug
tracker at:

- [Koha Bugzilla](http://bugs.koha-community.org)

He rau ringa e oti ai.
(Many hands finish the work)

Autogenerated release notes updated last on 25 Mar 2024 09:54:45.
