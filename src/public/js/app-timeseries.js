$(function() {
	var chartSearchData = null;
	var documentTimeChart = null;

	function updateDocumentTimeChart() {
		chartSearchData['value'] = '';
		$.ajax({
			url: '../main/getTimeseriesData.json',
			type: 'post',
			data: chartSearchData,
			success: function (data) {
				if (documentTimeChart) {
					documentTimeChart.destroy();
				}
				documentTimeChart = new Highcharts.Chart(documentTimeChartOptions);
				var selectedData = data['response']['data'];
				var drilldown = true;
				var seriesdata = [];
				for (var key in selectedData) {
					seriesdata.push({name: key, y: selectedData[key], drilldown: drilldown});
				}
				seriesdata.sort(itemSort);

				documentTimeChart.addSeries({data: seriesdata, color: '#2f7ed8', name: 'Documents'});
			}
		});
	};

	function monthSort(a, b) {
		var months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
		var aMonth = $.inArray(a.name, months);
		var bMonth = $.inArray(b.name, months);
		
		if (aMonth > bMonth) {
			return 1;
		}
		if (aMonth < bMonth) {
			return -1;
		}
		return 0;
	}

	function itemSort(a, b) {
		if (a['name'] > b['name']) {
			return 1;
		}
		if (a['name'] < b['name']) {
			return -1;
		}
		return 0;
	}

	$('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
		if ($(e.target).text() == "Time Series") {
			documentTimeChart.setSize($('#document_time_chart').width(), 400, false);
		}
	});

	$('body').on('run_search', function(evt, searchData) {
		chartSearchData = searchData;
		updateDocumentTimeChart();
	});

	var documentTimeChartOptions = {
		chart: {
			type: 'column',
			renderTo: 'document_time_chart',
			zoomType: 'x',
			events: {
				drilldown: function(e) {
					if (!e.seriesOptions) {
						var chart = this;
						chartSearchData['value'] = (chartSearchData['value'] == '') ? e.point.name : chartSearchData['value'] + '/' + e.point.name;

						chart.showLoading('Loading data...');
						$.ajax({
							url: '../main/getTimeseriesData.json',
							type: 'post',
							data: chartSearchData,
							success: function (data) {
								chart.hideLoading();
								var selectedData = data['response']['data'];
								var chartVal = chartSearchData['value'];
								var drilldown = (chartVal.split('/').length == 3) ? false : true;
								var title = (chartVal.length == 0) ? '' : ' ' + chartVal;
								chart.setTitle({text: 'Documents By Time' + title});
								var seriesdata = [];
								for (var key in selectedData) {
									seriesdata.push({name: key, y: selectedData[key], drilldown: drilldown});
								}
								seriesdata.sort((chartSearchData['value'].split('/').length == 1) ? monthSort : itemSort);
								chart.addSeriesAsDrilldown(e.point, {name: e.point.name, data: seriesdata});
							}
						});
					}
				},
				drillup: function(e) {
					var chart = this;
					chartSearchData['value'] = chartSearchData['value'].split('/').slice(0, -1).join('/');
					var chartVal = chartSearchData['value'];
					var title = (chartVal.length == 0) ? '' : ' ' + chartVal;
					chart.setTitle({text: 'Documents By Time' + title});
				},
				selection: function(e) {
					e.preventDefault();
					var chartVal = chartSearchData['value'];
					if (chartVal == '') {
						var points = this.series[0].points;
						var startYear = parseInt(points[0].name) + Math.floor(e.xAxis[0].min + .5);
						var endYear = parseInt(points[0].name) + Math.ceil(e.xAxis[0].max + .5);
						$('#startDate').val('01/01/' + startYear.toString());
						$('#endDate').val('01/01/' + endYear.toString());
						$('#search_div .date-input').trigger('change');
					} else if (chartVal.split('/').length == 1) {
						//Month view
						var year = chartVal;
						var startMonth = String('00' + Math.floor(e.xAxis[0].min + 1.5)).slice(-2);
						var endMonth = Math.ceil(e.xAxis[0].max + 1.5);
						var endDate = (endMonth == 13) ? '01/01/' + (parseInt(chartVal) + 1).toString() : String('00' + endMonth).slice(-2) + '/01/' + chartVal;
						$('#startDate').val(startMonth + '/01/' + chartVal);
						$('#endDate').val(endDate);
						$('#endDate').trigger('change');
					} else if (chartVal.split('/').length == 2) {
						//Daily view
						var year = chartVal.split('/')[0];
						var month = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"].indexOf(chartVal.split('/')[1]) + 1;
						var points = this.series[0].points;
						var startDay = String('00' + Math.floor(e.xAxis[0].min + 1.5)).slice(-2);
						var endDay = Math.ceil(e.xAxis[0].max + 1.5);
						var endDate = String('00' + month).slice(-2) + '/' + String('00' + endDay).slice(-2) + '/' + year;
						$('#startDate').val(String('00' + month).slice(-2) + '/' + startDay + '/' + year);
						if (endDay > points.length) {
							month = parseInt(month) + 1;
							if (month == 13) {
								month = 1;
								year = parseInt(year) + 1;
							}
							endDate = String('00' + month).slice(-2) + '/01/' + year.toString();
						}
						$('#endDate').val(endDate);
						$('#endDate').trigger('change');
					}
				}
			}
		},
		title: {
			text: 'Documents By Time'
		},
		xAxis: {
			type: 'category',
			labels: {
				rotation: 45,
				formatter: function() {
					return this.value;
				}
			}
		},
		yAxis: {
			min: 0,
			title: {
				text: 'Count'
			},
			allowDecimals: false
		},
		legend: {
			enabled: false
		},
		series: [],
		drilldown: {
			series: []
		}
	};
});