$(function() {
	var search_object = {facets: [], startIndex: 1, count: parseInt($('#PAGELENGTH').val())};
	var message_view_state = {query: '', uri: ''};
	var NOT_OPERATOR = $('#SEARCH_NOT_OPERATOR').val();

	$(window).bind('popstate', function(evt) {
		var state = evt.originalEvent.state;
		var id = state['id'];
		var hash = state['hash'];

		updateView(state);

		$('#main_tabs a[href="' + id + '"]').tab('show');
	});

	$('.search_button').on('click', function(evt, ui) {
		search_object['q'] =  $(this).parents('.tab-pane').find('textarea,input').val();
		search_object['startIndex'] = 1;
		run_search(search_object);
	});

	$('.search_text').on('keydown', function(evt, ui) {
		if (evt.keyCode == 13) {
			var tagname = $(this).prop('tagName');
			if ((tagname.toLowerCase() == 'textarea' && (evt.metaKey || evt.ctrlKey)) || (tagname.toLowerCase() == 'input')) {
				evt.preventDefault();
				$(this).parent().find('button').click();
			}
		}
	});

	$('#main_tabs a[data-toggle="tab"]').on('shown.bs.tab', function(evt, ui) {
		var currentTab = evt.target;
		var id = $(currentTab).attr('href');
		var hash = window.location.hash;
		if (hash.indexOf(id) != 0) {
			var state = {'id': id, 'hash': hash, messageViewState: message_view_state};
			var newhash = id;
			if (id.indexOf('#documents') == 0) {
				newhash += '/' + message_view_state['uri'];
			}
		    history.pushState(state, 'MarkLogic', newhash);
		}
	});

	$('body').on('click', '.page_link', function(evt, ui) {
		evt.preventDefault();
		if ($(this).parent().hasClass('disabled')) {
			return;
		}
		search_object['startIndex'] = $(this).data('startIndex');
		run_search(search_object);
		$("html, body").animate({ scrollTop: 0 }, "slow");
	});

	$('body').on('click', '.facet_link', function(evt, ui) {
		evt.preventDefault();
		var facet = $(this).data('value');
		facet = $(this).hasClass('list-group-item-danger') ? NOT_OPERATOR + facet : facet;
		$(this).hasClass('active') ? search_object['facets'].splice(search_object['facets'].indexOf(facet), 1) : search_object['facets'].push(facet);
		search_object['startIndex'] = 1;
		run_search(search_object);
	});

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

	$('body').on('click', '.search_result', function(evt, ui) {
		evt.preventDefault();
		var uri = $(this).data('uri');
		var query = ($(this).hasClass('search_result')) ? search_object['q'] : '';
		message_view_state = {'uri': uri, 'query': query};
		load_message(message_view_state);
		$('a[href="#documents"]').tab('show');
	});

	$('#search_div .date-input').on('change keyup', function(evt, ui) {
		var val = $(this).val();
		if (val.match(/^$|\d{2}\/\d{2}\/\d{4}/)) {
			run_search(search_object);
		}
	});

	function updateView(state) {
		var mvs = state['messageViewState'];
		if (mvs['uri'] != message_view_state['uri'] || mvs['query'] != message_view_state['query']) {
			message_view_state = mvs;
			load_message(message_view_state);
		}
	}

	// Load the document
	function load_message(mvs) {
		$('#document_id_input').val(mvs['uri']);
		$('#doc_viewer').attr('src', '../main/renderDocument.html?uri=' + mvs['uri']);
	}

	// Run a search
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
				$('#results_div').html($('#results_tmpl').render(results));
				$('span.snippet-term-highlight').replaceWith(function(){
					return $("<strong />").append($(this).contents());
				});

				var facets = [];
				var facet_data = data['facets'];
				for (var category in facet_data) {
					for (var facet in facet_data[category]) {
						facets.push({key: facet, value: facet_data[category][facet]});
					}
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

				$('#facet_div').html($('#facets_tmpl').render(facets));

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
	}

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
	}

	if (window.location.hash == '') {
		var id = '#search';
		var state = {'id': id, 'hash': '#search/', messageViewState: message_view_state};
		history.replaceState(state, 'MarkLogic', id + '/');
	} else {
		var hash = window.location.hash;
		var state = {'id': null, 'hash': '#search/', messageViewState: message_view_state};
		if (hash.indexOf('#documents/') == 0) {
			var uri = hash.substring(hash.indexOf('#documents/') + 10);
			message_view_state['uri'] = uri;
			$('#main_tabs a[href="#documents"]').tab('show');
			state['id'] = '#documents';
		}
		history.replaceState(state, 'MarkLogic', hash);
	}

	$('#search_button').click();
	$('#quicksearch_text').focus();
	$('#startDate').datepicker({multidate: false, autoclose: true});
	$('#endDate').datepicker({multidate: false, autoclose: true});

	load_message(message_view_state);
});