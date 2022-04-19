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
					document.getElementsByClassName('SS_DataBaseIndex')[0].style.display = 'none';
				} else if(tabtype[1].match(/BOOKS/)) {
					document.getElementsByClassName('SS_DataBaseIndex')[0].style.display = 'none';
				} else if (tabtype[1].match(/ALL/)) {
					document.getElementsByClassName('SS_DataBaseIndex')[0].style.display = 'block';
					document.getElementsByClassName('SS_TitleSearchForm')[0].style.display = 'none';
					document.getElementsByClassName('SS_SearchToolsGroup')[0].style.display = 'none';
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
		document.getElementsByClassName('SS_TitleSearchForm')[0].style.display = 'none';
		document.getElementsByClassName('SS_AtoZLinks')[0].style.display = 'none';
		document.getElementsByClassName('SS_CategorySelector')[0].style.display = 'none';
		var string = document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML;
		var newString = string.replace(/<br>/g,'');
		document.getElementsByClassName("SS_EJPMainCell")[0].innerHTML = newString;
	}
