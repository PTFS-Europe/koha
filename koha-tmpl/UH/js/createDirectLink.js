$(document).ready(function() {
    console.log( "Working!!" );

	var request = $.ajax({
            url: "https://library.herts.ac.uk/cgi-bin/koha/UH/getReport.pl",
            data: { URL: "https://library.herts.ac.uk/cgi-bin/koha/svc/report?id=6" },
            type: "POST",
            crossDomain: true,
            dataType: "json"

	});

    request.done(function( msg ) {
            // alert("Worked : " + msg[0]);
			// console.log(msg);

			$.each(msg, function(idx, obj) {
				//console.log(obj[1]);
				// remove studynet url
				if (/studynet/.test(obj[3])) {
					// console.log(obj[2]);
					var urls = obj[3].split(" ");
					// console.log("Second URL is " + urls[0])
					var newURL;
					for (u in urls) {
						if (!/studynet/.test(urls[u])) {
							newURL = urls[u];
						}
					}
					obj[3] = newURL;
					// console.log("This is the new URL " + obj[3]);
				}
				$('#datababasetable').append('<tr><td>' + obj[2] + '</td><td><a href=\"https://library.herts.ac.uk/cgi-bin/koha/resourcelink.pl?biblionumber=' + obj[0] + '\">https://library.herts.ac.uk/cgi-bin/koha/resourcelink.pl?biblionumber=' + obj[0] + '</a></td></tr>');
			});
	});

    request.fail(function( jqXHR, textStatus ) {
        // console.log(jqXHR);
        alert( "Request failed: " + textStatus );
    });
});
