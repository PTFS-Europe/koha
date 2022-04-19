	var query = window.location.search.substring(1);
	var params = query.split("&");

	console.log("There are " + params.length + " objects in the array");

	var noTab = true;

	for (i = 0; i < params.length; i++) {
			if (params[i].match(/^tab/)) {
				noTab = false;
				var tabtype = params[i].split("=");
				console.log("The type is " + tabtype[1]);

				if(tabtype[1].match(/JOURNALS/)) {
					var a = document.getElementsByClassName('SS_EJP_TabUnSelectedAll')[0];
					a.href = "https://ud7ed2gm9k.search.serialssolutions.com/?L=UD7ED2GM9K&tab=ALL"; 
					var b = document.getElementsByClassName('SS_EJP_TabUnSelectedBooks')[0];
					b.href = "https://ud7ed2gm9k.search.serialssolutions.com/?L=UD7ED2GM9K&tab=BOOKS"; 
					if (typeof document.getElementsByClassName('SS_DataBaseIndex')[0] !== "undefined") {
					document.getElementsByClassName('SS_DataBaseIndex')[0].style.display = 'none';
					}

				} else if(tabtype[1].match(/BOOKS/)) {
					var a = document.getElementsByClassName('SS_EJP_TabUnSelectedAll')[0];
					a.href = "https://ud7ed2gm9k.search.serialssolutions.com/?L=UD7ED2GM9K&tab=ALL"; 
					var b = document.getElementsByClassName('SS_EJP_TabUnSelectedJournals')[0];
					b.href = "https://ud7ed2gm9k.search.serialssolutions.com/?L=UD7ED2GM9K&tab=JOURNALS"; 
					if (typeof document.getElementsByClassName('SS_DataBaseIndex')[0] !== "undefined") {
					document.getElementsByClassName('SS_DataBaseIndex')[0].style.display = 'none';
					}
				} else if (tabtype[1].match(/ALL/)) {
					console.log("We are back in the ALL tab");
					//document.getElementsByClassName('SS_DataBaseIndex')[0].style.display = 'block';
					document.getElementsByClassName('SS_ResultsAtoZLinks')[0].style.display = 'block';
					document.getElementsByClassName('SS_TitleSearchForm')[0].style.display = 'none';
					//document.getElementsByClassName('SS_SearchToolsGroup')[0].style.display = 'none';
					document.getElementsByClassName('SS_AtoZLinks')[0].style.display = 'none';
					document.getElementsByClassName('SS_CategorySelector')[0].style.display = 'none';
					var string = document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML;
					var newString = string.replace(/<br>/g,'');
					document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML = newString;
				} else {
					document.getElementsByClassName('SS_TitleSearchForm')[0].style.display = 'none';
					document.getElementsByClassName('SS_AtoZLinks')[0].style.display = 'none';
					document.getElementsByClassName('SS_CategorySelector')[0].style.display = 'none';
					var string = document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML;
					var newString = string.replace(/<br>/g,'');
					document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML = newString;
				}
			}
	}

	if (noTab) {
		console.log("There is no tab at the moment");
		document.getElementsByClassName('SS_TitleSearchForm')[0].style.display = 'none';
		document.getElementsByClassName('SS_AtoZLinks')[0].style.display = 'none';
		document.getElementsByClassName('SS_CategorySelector')[0].style.display = 'none';
		var string = document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML;
		var newString = string.replace(/<br>/g,'');
		document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML = newString;
	}
