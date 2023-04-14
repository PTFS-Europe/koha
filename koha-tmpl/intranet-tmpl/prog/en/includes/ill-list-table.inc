[% IF prefilters.length > 0 %]
<table id="ill-requests" data-prefilters="[% prefilters | html %]">
[% ELSE %]
<table id="ill-requests">
[% END %]
    <thead>
        <tr id="illview-header">
            <th scope="col">Request ID</th>
            <th scope="col">Author</th>
            <th scope="col">Title</th>
            <th scope="col">Article title</th>
            <th scope="col">Issue</th>
            <th scope="col">Volume</th>
            <th scope="col">Year</th>
            <th scope="col">Pages</th>
            <th scope="col">Request type</th>
            <th scope="col">Order ID</th>
            <th scope="col">Patron</th>
            <th scope="col">Bibliographic record ID</th>
            <th scope="col">Library</th>
            <th scope="col">Status</th>
            <th scope="col" class="placed">&nbsp;</th>
            <th scope="col" class="placed_formatted">Placed on</th>
            <th scope="col" class="updated">&nbsp;</th>
            <th scope="col" class="updated_formatted">Updated on</th>
            <th scope="col">Replied</th>
            <th scope="col" class="completed">&nbsp;</th>
            <th scope="col" class="completed_formatted">Completed on</th>
            <th scope="col">Access URL</th>
            <th scope="col">Cost</th>
            <th scope="col">Price paid</th>
            <th scope="col">Comments</th>
            <th scope="col">OPAC notes</th>
            <th scope="col">Staff notes</th>
            <th scope="col">Backend</th>
            <th scope="col" class="actions"></th>
        </tr>
    </thead>
    <tbody id="illview-body">
    </tbody>
</table>

[% IF prefilters.length > 0 %]
<table id="ill_requests" data-prefilters="[% prefilters | html %]">
[% ELSE %]
<table id="ill_requests">
[% END %]
    <thead>
        <tr id="ill_requests_header">
            <th scope="col">Request ID</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="author"         data-related-search-on="value">Author</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="title"         data-related-search-on="value">Title</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="article_title" data-related-search-on="value">Article title</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="issue"         data-related-search-on="value">Issue</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="volume"        data-related-search-on="value">Volume</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="year"          data-related-search-on="value">Year</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="pages"         data-related-search-on="value">Pages</th>
            <th scope="col" data-datatype="related-object" data-related="ill_extended_attributes" data-related-key="type" data-related-value="type"          data-related-search-on="value">Request type</th>
            <th scope="col">Order ID</th>
            <th scope="col">Patron</th>
            <th scope="col">Bibliographic record ID</th>
            <th scope="col">Library</th>
            <th scope="col">Status</th>
            <th scope="col" class="placed_formatted">Placed on</th>
            <th scope="col" class="updated_formatted">Updated on</th>
            <th scope="col">Replied</th>
            <th scope="col" class="completed_formatted">Completed on</th>
            <th scope="col">Access URL</th>
            <th scope="col">Cost</th>
            <th scope="col">Price paid</th>
            <th scope="col">Comments</th>
            <th scope="col">OPAC notes</th>
            <th scope="col">Staff notes</th>
            <th scope="col">Backend</th>
            <th scope="col" class="actions"></th>
        </tr>
    </thead>
    <tbody id="illview-body">
    </tbody>
</table>