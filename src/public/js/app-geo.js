$(function() {
	var mapShown = false;
	var heatmap = null;
	var selectedShape = null;
	var mapSearchData = null;

	function updateMap() {
		$.ajax({
			url: '../main/getGeoData.json',
			type: 'post',
			data: mapSearchData,
			success: function (data) {
				var points = data['response']['data']['points'];
				var pointArray = [];
				for (var i=0; i<points.length; i++) {
					pointArray.push(new google.maps.LatLng(points[i][0], points[i][1]));
				}
				if (heatmap) {
					heatmap.setMap(null);
				}
				heatmap = new google.maps.visualization.HeatmapLayer({
					data: pointArray
				});

				heatmap.setMap(map);
			}
		});
	};

	function serializeShapes() {
		var circles = shapes['circles'];
		var rectangles = shapes['rectangles'];
		var polygons = shapes['polygons'];

		var json = {
		};

		if (circles.length > 0) {
			json['circles'] = [];
			for (var c in circles) {
				json['circles'].push({'center': [circles[c]['center'].lat(), circles[c]['center'].lng()], 'radius': circles[c]['radius']});
			}
		}

		if (rectangles.length > 0) {
			json['rectangles'] = [];
			for (var r in rectangles) {
				var rect = rectangles[r];
				json['rectangles'].push({'bounds': [rect.bounds.getSouthWest().lat(), rect.bounds.getSouthWest().lng(), rect.bounds.getNorthEast().lat(), rect.bounds.getNorthEast().lng()]});
			}
		}
		
		if (polygons.length > 0) {
			json['polygons'] = [];
			for (var p in polygons) {
				var polygon = polygons[p];
				var paths = [];
				for (var i=0; i < polygon.getPaths().getArray().length; i++) {
					var arr = polygon.getPaths().getAt(i).getArray();
					var points = [];
					for (var j=0; j < arr.length; j++) {
						points.push([arr[j].lat(), arr[j].lng()]);
					}
					paths.push({'path': points});
				}				

				json['polygons'].push({'paths': paths});
			}
		}

		$('#geoData').val(JSON.stringify(json));
		$('#startDate').trigger('change');
	}

	function RemoveRegionButton(controlDiv, map) {
		controlDiv.style.padding = '5px';

		// Set CSS for the control border
		var controlUI = document.createElement('div');
		controlUI.style.backgroundColor = 'white';
		controlUI.style.borderStyle = 'solid';
		controlUI.style.borderWidth = '1px';
		controlUI.style.cursor = 'pointer';
		controlUI.style.textAlign = 'center';
		controlUI.title = 'Click to delete the selected region.';
		controlDiv.appendChild(controlUI);

		// Set CSS for the control interior
		var controlText = document.createElement('div');
		controlText.style.fontFamily = 'Arial,sans-serif';
		controlText.style.fontSize = '12px';
		controlText.style.paddingLeft = '4px';
		controlText.style.paddingRight = '4px';
		controlText.innerHTML = '<b>Delete Region</b>';
		controlUI.appendChild(controlText);

		google.maps.event.addDomListener(controlUI, 'click', function() {
			if (selectedShape) {
				for (var type in shapes) {
					for (var i=0; i<shapes[type].length; i++) {
						if (shapes[type][i] == selectedShape) {
							shapes[type].splice(i, 1);
							break;
						}
					}
				}
				selectedShape.setMap(null);
				selectedShape = null;
				serializeShapes();
				$(removeShapesDiv).hide();
			}
		});

	}

	$('a[data-toggle="tab"]').on('shown.bs.tab', function (e) {
		if ($(e.target).text() == "Map") {
			if (!mapShown) {
				google.maps.event.trigger(map, "resize");
				map.setCenter({lat: 0, lng: 0});
				mapShown = true;
			}
		}
	});
	
	$('body').on('run_search', function(evt, searchData) {
		mapSearchData = searchData;
		updateMap();
	});

	var mapOptions = {
		center: {lat: 0, lng: 0},
		zoom: 1
	};

	var map = new google.maps.Map($('#map_container')[0], mapOptions);

	var removeShapesDiv = document.createElement('div');
	var removeShapes = new RemoveRegionButton(removeShapesDiv, map);
	removeShapesDiv.index = 1;
	map.controls[google.maps.ControlPosition.TOP_RIGHT].push(removeShapesDiv);
	$(removeShapesDiv).hide();

	var drawingManager = new google.maps.drawing.DrawingManager({
		drawingMode: null,
		drawingControl: true,
		drawingControlOptions: {
			position: google.maps.ControlPosition.TOP_CENTER,
			drawingModes: [
				google.maps.drawing.OverlayType.CIRCLE,
				google.maps.drawing.OverlayType.POLYGON,
				google.maps.drawing.OverlayType.RECTANGLE
			]
		},
		circleOptions: {
			fillColor: '#888888',
			fillOpacity: .2,
			strokeWeight: 2,
			clickable: true,
			editable: true,
			zIndex: 1
		},
		polygonOptions: {
			fillColor: '#888888',
			fillOpacity: .2,
			strokeWeight: 2,
			clickable: true,
			editable: true,
			zIndex: 2
		},
		rectangleOptions: {
			fillColor: '#888888',
			fillOpacity: .2,
			strokeWeight: 2,
			clickable: true,
			editable: true,
			zIndex: 3
		}
	});
	drawingManager.setMap(map);
	var shapes = {
		circles: [],
		rectangles: [],
		polygons: []
	};

	google.maps.event.addListener(drawingManager, 'overlaycomplete', function(event) {
		if (event.type == google.maps.drawing.OverlayType.CIRCLE) {
			google.maps.event.addListener(event.overlay, 'radius_changed', function () {
				serializeShapes();
			});
			google.maps.event.addListener(event.overlay, 'center_changed', function () {
				serializeShapes();
			});

			shapes['circles'].push(event.overlay);
		} else if (event.type == google.maps.drawing.OverlayType.RECTANGLE) {
			google.maps.event.addListener(event.overlay, 'bounds_changed', function () {
				serializeShapes();
			});
			shapes['rectangles'].push(event.overlay);
		} else if (event.type == google.maps.drawing.OverlayType.POLYGON) {
			google.maps.event.addListener(event.overlay.getPath(), 'set_at', function() {
				serializeShapes();
			});

			google.maps.event.addListener(event.overlay.getPath(), 'insert_at', function() {
				serializeShapes();
			});
			shapes['polygons'].push(event.overlay);
		}

		if (selectedShape) {
			selectedShape.setOptions({strokeWeight: 2});
		}
		selectedShape = event.overlay;
		selectedShape.setOptions({strokeWeight: 3});
		$(removeShapesDiv).show();

		google.maps.event.addListener(event.overlay, 'click', function() {
			if (selectedShape) {
				selectedShape.setOptions({strokeWeight: 2});
			}
			selectedShape = this;
			selectedShape.setOptions({strokeWeight: 3});
			$(removeShapesDiv).show();
		});
		serializeShapes();
	});
});