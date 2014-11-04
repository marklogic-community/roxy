$(function() {
	var search_object = {facets: [], startIndex: 1, count: parseInt($('#PAGELENGTH').val())};
	var document_viewer_state = {query: '', uri: ''};
	var NOT_OPERATOR = $('#SEARCH_NOT_OPERATOR').val();

	/**
	* Fired when the user pushes the back button in our app.
	* Retreives the previous view information and updates the app based on
	* that data.
	*/
	$(window).bind('popstate', function(evt) {
		var state = evt.originalEvent.state;
		var id = state['id'];
		var dvs = state['documentViewerState'];
		if (dvs['uri'] != document_viewer_state['uri'] || dvs['query'] != document_viewer_state['query']) {
			document_viewer_state = dvs;
			load_document(document_viewer_state);
		}

		$('#main_tabs a[href="' + id + '"]').tab('show');
	});

	/**
	* Fired when the user pushes the search button. Updates the global
	* search object and runs the search.
	*/
	$('.search_button').on('click', function(evt, ui) {
		search_object['q'] =  $(this).parents('.tab-pane').find('textarea,input').val();
		search_object['startIndex'] = 1;
		run_search(search_object);
	});

	/**
	* Fired when the user types in the search box. Traps the "enter" key
	* and runs a search if necessary.
	*/
	$('.search_text').on('keydown', function(evt, ui) {
		if (evt.keyCode == 13) {
			var tagname = $(this).prop('tagName');
			if ((tagname.toLowerCase() == 'textarea' && (evt.metaKey || evt.ctrlKey)) || (tagname.toLowerCase() == 'input')) {
				evt.preventDefault();
				$(this).parent().find('button').click();
			}
		}
	});

	/**
	* Fired when the user changes the displayed tab (Search or Document Viewer)
	*/
	$('#main_tabs a[data-toggle="tab"]').on('shown.bs.tab', function(evt, ui) {
		var currentTab = evt.target;
		var id = $(currentTab).attr('href');
		var hash = window.location.hash;
		if (hash.indexOf(id) != 0) {
			var state = {'id': id, 'hash': hash, documentViewerState: document_viewer_state};
			var newhash = id;
			if (id.indexOf('#documents') == 0) {
				newhash += '/' + document_viewer_state['uri'];
			}
		    history.pushState(state, 'MarkLogic', newhash);
		}
	});

	/**
	* Fired when the user clicks one of the pager links
	*/
	$('body').on('click', '.page_link', function(evt, ui) {
		evt.preventDefault();
		if ($(this).parent().hasClass('disabled')) {
			return;
		}
		search_object['startIndex'] = $(this).data('startIndex');
		run_search(search_object);
		$("html, body").animate({ scrollTop: 0 }, "slow");
	});

	/**
	* Fired when the user clicks on a facet
	*/
	$('body').on('click', '.facet_link', function(evt, ui) {
		evt.preventDefault();
		var facet = $(this).data('value');
		facet = $(this).hasClass('list-group-item-danger') ? NOT_OPERATOR + facet : facet;
		$(this).hasClass('active') ? search_object['facets'].splice(search_object['facets'].indexOf(facet), 1) : search_object['facets'].push(facet);
		search_object['startIndex'] = 1;
		run_search(search_object);
	});

	/**
	* Fired when the user right-clicks on a facet
	*/
	$('body').on('contextmenu', '.facet_link', function(evt, ui) {
		if ((!$(this).hasClass('list-group-item-danger') && $(this).hasClass('active')) || ($(this).hasClass('list-group-item-danger'))) {
			$(this).trigger('click');
			return false;
		}
		var facet = $(this).data('value');
		search_object['facets'].push(NOT_OPERATOR + facet);
		search_object['startIndex'] = 1;
		run_search(search_object);
		return false;
	});

	/**
	* Fired when the user clicks on a search result
	*/
	$('body').on('click', '.search_result', function(evt, ui) {
		evt.preventDefault();
		var uri = $(this).data('uri');
		var query = ($(this).hasClass('search_result')) ? search_object['q'] : '';
		document_viewer_state = {'uri': uri, 'query': query};
		load_document(document_viewer_state);
		$('a[href="#documents"]').tab('show');
	});

	/**
	* Fired when the user types in the date field or the value changes.
	*/
	$('#search_div .date-input').on('change keyup', function(evt, ui) {
		var val = $(this).val();
		if (val.match(/^$|\d{2}\/\d{2}\/\d{4}/)) {
			run_search(search_object);
		}
	});

	/** 
	* Load the document in the document viewer
	* @param dvs The document_viewer_state object.
	*/
	function load_document(dvs) {
		$('#document_id_input').val(dvs['uri']);
		$('#doc_viewer').attr('src', '../main/renderDocument.html?uri=' + dvs['uri']);
	}

	/** 
	* Run a search. Update the result display and handle errors.
	* @param search_object The global search_object object that contains search parameters like
	*   startIndex, count, q (the query string), and facets (the list of selected facets)
	* 
	*/
	function run_search(search_object) {
		$('.search_button_text').hide();
		$('.search_button_image').show();
		var facets = [];
		$.each(search_object['facets'], function(idx, val) {
			var tokens = val.split(':');
			var facetval = tokens.slice(1).join(":"); 
			if (facetval.search(" ") == -1) {
				facets.push(val);
			} else {
				facets.push(tokens[0] + ':"' + facetval + '"');
			}
		});

		var searchData = {
				q: search_object['q'],
				facets: facets.join('_FACET_'),
				count: search_object['count'],
				startIndex: search_object['startIndex'],
				returnSnippets: true,
				returnFacets: true
			};

		if ($('#startDate').length != 0) {
			if ($('#startDate').val().match(/\d{2}\/\d{2}\/\d{4}/)) {
				var date = $('#startDate').val().replace(/(\d{2})\/(\d{2})\/(\d{4})/, '$3-$1-$2') + 'T00:00:00Z';
				searchData['startDate'] = date;
			}
			if ($('#endDate').val().match(/\d{2}\/\d{2}\/\d{4}/)) {
				var date = $('#endDate').val().replace(/(\d{2})\/(\d{2})\/(\d{4})/, '$3-$1-$2') + 'T00:00:00Z';
				searchData['endDate'] = date;
			}
		}
		if ($('#geoData').val()) {
			searchData['geoBoundaries'] = $('#geoData').val();
		}
		$.ajax({
			url: '../main/search.json',
			type: 'post',
			data: searchData
		}).done(function(data) {
				var results = data['results'];
				results = (results instanceof Array) ? results : [results];
				var resTemplate = Handlebars.compile($('#results_tmpl').html());
				$('#results_div').html(resTemplate(results));
				$('span.snippet-term-highlight').replaceWith(function(){
					return $("<strong />").append($(this).contents());
				});

				var facets = [];
				var facet_data = data['facets'];
				for (var facet in facet_data) {
					facets.push({key: facet, value: facet_data[facet]});
				}

				for (var i=0; i < search_object['facets'].length; i++) {
					var facet = (search_object['facets'][i].slice(0, NOT_OPERATOR.length) == NOT_OPERATOR) ? search_object['facets'][i].substring(NOT_OPERATOR.length) : search_object['facets'][i];
					var facet_name = facet.split(':')[0];
					var facet_val = facet.split(':').slice(1).join(':');
					if (facets.length > 0) {
						var idx = -1;
						for (var j=0; j < facets.length; j++) {
							if (facets[j]['key'] == facet_name) {
								idx = j;
								break;
							}
						}
						if (idx == -1) {
							facets.push({'key': facet_name, 'value': [{name: facet_val, count: 0}]});
						} else {
							var idx2 = -1;
							for (var k=0; k < facets[idx]['value'].length; k++) {
								if (facets[idx]['value'][k]['name'] == facet_val) {
									idx2 = k;
									break;
								}
							}
							if (idx2 == -1) {
								facets[idx]['value'].push({name: facet_val, count: 0});
							}
						}
					} else {
						facets.push({'key': facet_name, 'value': [{name: facet_val, count: 0}]});
					}
				}

				var facetTemplate = Handlebars.compile($('#facets_tmpl').html());
				$('#facet_div').html(facetTemplate(facets));

				for (var i=0; i < search_object['facets'].length; i++) {
					if (search_object['facets'][i].substring(0, NOT_OPERATOR.length) == NOT_OPERATOR) {
						var facet = search_object['facets'][i].substring(NOT_OPERATOR.length);
						$('[data-value="' + facet + '"] span.glyphicon').removeClass('hidden');
						$('[data-value="' + facet + '"]').addClass('active list-group-item-danger');
					} else {
						$('[data-value="' + search_object['facets'][i] + '"]').addClass('active').removeClass('list-group-item-danger');
						$('[data-value="' + search_object['facets'][i] + '"] span.glyphicon').addClass('hidden');
					}
				}

				do_pager(data);
		}).always(function() {
			$('.search_button_text').show();
			$('.search_button_image').hide();			
		}).fail(function(jqXHR) {
			$('#facet_div').empty();
			$('#pager_div').addClass('hidden');
			$('#results_div').html('<div class="alert alert-danger">An error occurred processing your search</div>');
		});
		$('body').trigger('run_search', [searchData]);
	} //end run_search

	/** 
	* Add the pager to the bottom of the results list.
	* @param data The json response from the call to search.json
	*/
	function do_pager(data) {
		var start = data['startIndex'];
		var pagesize = data['count'];
		var resultcount = data['total'];
		var currentpage = (start + pagesize - 1) / pagesize;
		var totalpages = Math.ceil(resultcount / pagesize);

		if (resultcount == 0) {
			$('#pager_div').addClass('hidden');
			$('#results_div').html('<div class="alert alert-info">No results</div>');
			return;
		} else {
			$('#pager_div').removeClass('hidden');
		}

		var last_item = (pagesize * currentpage > resultcount) ? resultcount : pagesize * currentpage;  

		$('#pager_text').text(start.toString() + ' to ' + (last_item).toString() + ' of about ' + resultcount.toString());

		var offset = 0;
		if (currentpage > 3) {
			if (currentpage > totalpages - 2) {
				offset = totalpages - 5;
			} else {
				offset = currentpage - 3;
			}
		}

		if (currentpage > 1) {
			$('#page_first').removeClass('disabled');
			$('#page_prev').removeClass('disabled');
		} else {
			$('#page_first').addClass('disabled');
			$('#page_prev').addClass('disabled');
		}

		if (currentpage < totalpages) {
			$('#page_last').removeClass('disabled');
			$('#page_next').removeClass('disabled');
		} else {
			$('#page_last').addClass('disabled');
			$('#page_next').addClass('disabled');
		}

		for (var i=1 + offset; i <= 5 + offset; i++) {
			var pagenum = i - offset;
			// Hide page numbers that aren't needed
			if (i * pagesize >= resultcount + pagesize) {
				$('#page_' + pagenum.toString()).addClass('hidden');
			} else {
				$('#page_' + pagenum.toString()).removeClass('hidden');
			}

			if (i == currentpage) {
				$('#page_' + pagenum.toString()).addClass('active');
			} else {
				$('#page_' + pagenum.toString()).removeClass('active');
			}

			$('#page_' + pagenum.toString() + ' a').text(i.toString()).data('startIndex', ((i-1) * pagesize) + 1);
		}

		$('#page_first a').data('startIndex', 1);
		$('#page_prev a').data('startIndex', ((currentpage - 1) * pagesize) - pagesize + 1);
		$('#page_next a').data('startIndex', ((currentpage + 1) * pagesize) - pagesize + 1);
		$('#page_last a').data('startIndex', (totalpages * pagesize) - pagesize + 1);
	} //end do_pager

	/**
	* When the page is done loading, check the hash to see if the user got here
	* from a link that has a hash. If so, parse the hash and see what we need
	* to show the user.
	*/
	if (window.location.hash == '') { //No hash present
		var id = '#search';
		var state = {'id': id, 'hash': '#search/', documentViewerState: document_viewer_state};
		history.replaceState(state, 'MarkLogic', id + '/');
	} else { //Hash present. Parse the hash.
		var hash = window.location.hash;
		var state = {'id': null, 'hash': '#search/', documentViewerState: document_viewer_state};
		if (hash.indexOf('#documents/') == 0) { //The user should be shown the document viewer
			var uri = hash.substring(hash.indexOf('#documents/') + 10);
			document_viewer_state['uri'] = uri;
			$('#main_tabs a[href="#documents"]').tab('show');
			state['id'] = '#documents';
		}
		history.replaceState(state, 'MarkLogic', hash);
	}

	$('#search_button').click(); //Run an empty search when the page first loads
	$('#quicksearch_text').focus(); //Focus the search input box so the user can start typing immediately
	$('#startDate').datepicker({multidate: false, autoclose: true}); //Create a datepicker widget
	$('#endDate').datepicker({multidate: false, autoclose: true}); //Create a datepicker widget

	load_document(document_viewer_state); //Initialize the document viewer
});